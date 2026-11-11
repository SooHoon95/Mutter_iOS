#!/usr/bin/env python3
"""승인 후 예약 발행. 기본 실행은 dry-run이며 POST는 --live에서만 가능하다."""
import argparse
import hashlib
import json
import sys
import time
from datetime import timedelta
from pathlib import Path

from social_jobs import (ROOT, PUBLISHING, atomic_json, digest, file_digest, load_env,
                         lock, now, parse_time, payload_from_queue, read_json, update_env,
                         validate_job)

TOKEN_KEYS = {'threads': 'THREADS', 'instagram': 'IG'}
# launchd는 TCC 때문에 ~/Desktop의 PUBLISH_DISABLED를 못 읽는다. 이 파일이 있을 때만 Terminal 래퍼를 띄운다.
LAUNCHD_ARMED = Path.home() / 'Library/Application Support/Mutter/publish-armed'


def token_fingerprint(value):
    return hashlib.sha256(value.encode()).hexdigest()


def token_env(env, metadata, current):
    enriched = dict(env)
    for channel, prefix in TOKEN_KEYS.items():
        entry = metadata.get(channel, {})
        if entry.get('fingerprint') != token_fingerprint(env.get(prefix + '_ACCESS_TOKEN', '')):
            raise ValueError(f'{channel}: 토큰 변경/등록 필요. 발급 시각과 만료 시각을 등록하세요.')
        if entry.get('kind') != 'long_lived_dashboard' or entry.get('expires_at', 0) <= current:
            raise ValueError(f'{channel}: 장기 토큰이 만료됐거나 발급 정보가 없습니다.')
        for key in ['issued_at', 'expires_at']:
            enriched[prefix + '_TOKEN_' + key.upper()] = str(entry[key])
        enriched[prefix + '_TOKEN_KIND'] = entry['kind']
    return enriched


def maintain_tokens(env, api_class, base=PUBLISHING):
    path = base / 'token_state.json'
    metadata = read_json(path, {})
    current = int(now().timestamp())
    enriched = token_env(env, metadata, current)
    for channel, prefix in TOKEN_KEYS.items():
        entry = metadata[channel]
        if entry['expires_at'] - current <= 14 * 86400:
            if current - entry['issued_at'] < 86400:
                raise ValueError('24시간 미만 토큰은 갱신하지 않습니다.')
            result = api_class(enriched).refresh_token(channel)
            value = result.get('access_token')
            lifetime = result.get('expires_in', 0)
            if not value or not isinstance(lifetime, int) or lifetime <= 86400:
                raise ValueError('토큰 갱신 결과가 유효하지 않습니다.')
            # env를 먼저 저장한다. 중간 종료 시 해시 불일치로 중단하여 재등록을 요구한다.
            update_env({prefix + '_ACCESS_TOKEN': value})
            env[prefix + '_ACCESS_TOKEN'] = value
            metadata[channel] = {'kind': 'long_lived_dashboard',
                'issued_at': current, 'expires_at': current + lifetime,
                'fingerprint': token_fingerprint(value), 'source': 'refresh_response'}
            atomic_json(path, metadata)
            enriched = token_env(env, metadata, current)
    return api_class(enriched)


def prepare_image(payload, base=PUBLISHING):
    from PIL import Image
    from render_card import render_card
    preview = base / 'previews' / (payload['job_id'] + '.png')
    render_card(payload['card']['title'], payload['card']['body'], preview,
                ROOT / 'marketing/assets/fonts/NotoSerifCJKkr-Regular.otf')
    jpeg = preview.with_suffix('.jpg')
    with Image.open(preview) as image:
        image.convert('RGB').save(jpeg, 'JPEG', quality=94, subsampling=0)
    if jpeg.stat().st_size > 8 * 1024 * 1024:
        raise ValueError('Instagram JPEG 8 MB 초과')
    return jpeg


def preview_job(queue, scheduled_at, env, final_text=None):
    metadata, _ = __import__('social_jobs').queue_content(queue)
    channel = {'threads': 'threads', 'instagram_card': 'instagram', 'instagram_reel': 'instagram'}.get(metadata.get('type'))
    prefix = TOKEN_KEYS.get(channel)
    if not prefix:
        raise ValueError('지원하지 않는 콘텐츠 형식입니다. instagram_reel은 완성 MP4와 별도 캡션이 필요합니다.')
    payload = payload_from_queue(queue, scheduled_at, env[prefix + '_USER_ID'],
                                 env.get('MARKETING_EXPECTED_USERNAME', 'mu_sic_letter'), final_text)
    if channel == 'instagram' and payload.get('media_type') != 'REELS':
        jpeg = prepare_image(payload)
        payload['image_path'] = str(jpeg.relative_to(ROOT))
        payload['image_sha256'] = file_digest(jpeg)
    return payload


def enqueue(payload, base=PUBLISHING):
    job_path = base / 'jobs' / (payload['job_id'] + '.json')
    if job_path.exists():
        raise ValueError('이 큐는 이미 예약됐습니다. 기존 작업을 중복 등록할 수 없습니다.')
    if payload['channel'] == 'instagram':
        reel = payload.get('media_type') == 'REELS'
        key, extension = ('video', '.mp4') if reel else ('image', '.jpg')
        source = ROOT / payload[key + '_path']
        limit = (45 if reel else 8) * 1024 * 1024
        if source.stat().st_size > limit:
            raise ValueError('승인 미디어 파일 크기 제한 초과')
        with source.open('rb') as stream:
            content = stream.read(limit + 1)
        if len(content) > limit:
            raise ValueError('승인 미디어 파일 크기 제한 초과')
        if hashlib.sha256(content).hexdigest() != payload[key + '_sha256']:
            raise ValueError('프리뷰 미디어 변경. 다시 검수하세요.')
        assets = base / 'assets'
        assets.mkdir(parents=True, exist_ok=True)
        target = assets / (payload[key + '_sha256'] + extension)
        if target.exists() and file_digest(target) != payload[key + '_sha256']:
            raise ValueError('승인 미디어 파일 충돌')
        if not target.exists():
            target.write_bytes(content)
            target.chmod(0o444)
        payload[key + '_path'] = str(target.relative_to(ROOT))
    job = {'payload': payload, 'approval': {'confirmed': True, 'sha256': digest(payload)}}
    validate_job(job, base)
    atomic_json(job_path, job, 0o444)
    return job_path


def save_state(base, payload, state):
    atomic_json(base / 'state' / (payload['job_id'] + '.json'), state)


def execute_job(payload, api, base=PUBLISHING, sleep=time.sleep):
    state_path = base / 'state' / (payload['job_id'] + '.json')
    state = read_json(state_path, {'phase': 'pending', 'attempts': 0})
    if state['phase'] in {'published', 'published_id_unresolved', 'uncertain', 'failed', 'cancelled', 'expired_hold'}:
        return state
    if state['phase'] in {'creating', 'publishing'}:
        state.update(phase='uncertain', reason='이전 네트워크 호출 도중 종료. 중복 방지를 위해 수동 확인 필요.')
        save_state(base, payload, state)
        return state
    if (base / 'PUBLISH_DISABLED').exists():
        return state
    if now() - parse_time(payload['scheduled_at']) > timedelta(hours=24):
        state.update(phase='expired_hold', reason='24시간 이상 지연. 시즌/시간 재검수 필요.')
        save_state(base, payload, state)
        return state
    try:
        if state['phase'] in {'pending', 'uploading'}:
            image_url = None
            video_url = None
            reel = payload.get('media_type') == 'REELS'
            if payload['channel'] == 'instagram':
                state['phase'] = 'uploading'
                save_state(base, payload, state)
                if reel:
                    video_url = api.upload_video(ROOT / payload['video_path'], payload['video_sha256'] + '.mp4')
                else:
                    image_url = api.upload_image(ROOT / payload['image_path'], payload['image_sha256'] + '.jpg')
            if (base / 'PUBLISH_DISABLED').exists():
                return state
            state.update(phase='creating', attempts=state['attempts'] + 1)
            save_state(base, payload, state)
            if (base / 'PUBLISH_DISABLED').exists():
                state['phase'] = 'uploading' if payload['channel'] == 'instagram' else 'pending'
                save_state(base, payload, state)
                return state
            if reel:
                container = api.create_reel(payload['text'], video_url)
            else:
                container = api.create_container(payload['channel'], payload['text'], image_url)
            state.update(phase='container_ready', container_id=container)
            save_state(base, payload, state)
            if payload['channel'] == 'threads':
                sleep(30)
        status = None
        for attempt in range(5):
            if (base / 'PUBLISH_DISABLED').exists():
                return state
            status = api.container_status(payload['channel'], state['container_id'])
            if status != 'IN_PROGRESS':
                break
            if attempt < 4:
                sleep(60)
        if status == 'PUBLISHED':
            state.update(phase='published_id_unresolved', published_at=now().isoformat(),
                         reason='컨테이너는 게시됨. 미디어 ID를 수동 확인하세요.')
        elif status in {'ERROR', 'EXPIRED'}:
            state.update(phase='failed', reason=f'컨테이너 상태 {status}. 자동 재생성 안 함.')
        elif status == 'FINISHED':
            if (base / 'PUBLISH_DISABLED').exists():
                return state
            state['phase'] = 'publishing'
            save_state(base, payload, state)
            if (base / 'PUBLISH_DISABLED').exists():
                state['phase'] = 'container_ready'
                save_state(base, payload, state)
                return state
            media_id = api.publish(payload['channel'], state['container_id'])
            if not media_id:
                raise ValueError('게시 결과 ID가 없음')
            state.update(phase='published', media_id=media_id, published_at=now().isoformat())
            # 퍼머링크 실패가 재게시를 유발하지 않도록 성공을 먼저 확정한다.
            save_state(base, payload, state)
            try:
                state['permalink'] = api.permalink(payload['channel'], media_id)
            except Exception:
                state['permalink_pending'] = True
        elif status != 'IN_PROGRESS':
            state.update(phase='uncertain', reason='알 수 없는 컨테이너 상태')
    except Exception as error:
        phase = state['phase']
        if phase in {'creating', 'publishing'}:
            state.update(phase='uncertain', reason='게시/생성 호출 결과 미확정. 수동 확인 필요.')
        elif phase != 'published':
            failures = state.get('read_failures', 0) + 1
            state.update(read_failures=failures, reason='미디어 업로드/상태 조회 실패')
            if failures >= 3 or not getattr(error, 'transient', False):
                state['phase'] = 'failed'
    save_state(base, payload, state)
    return state


def run_due(env, live=False, base=PUBLISHING, api_class=None):
    if (base / 'PUBLISH_DISABLED').exists():
        return [{'mode': 'disabled'}]
    current = now()
    candidates = []
    for path in sorted((base / 'jobs').glob('*.json')):
        payload = validate_job(read_json(path), base)
        prefix = TOKEN_KEYS[payload['channel']]
        if payload['account_id'] != env.get(prefix + '_USER_ID') or payload['username'] != env.get('MARKETING_EXPECTED_USERNAME', 'mu_sic_letter'):
            raise ValueError('승인한 게시 대상과 현재 인증 계정이 다릅니다.')
        state = read_json(base / 'state' / (payload['job_id'] + '.json'), {'phase': 'pending'})
        if state['phase'] not in {'pending', 'uploading', 'creating', 'publishing', 'container_ready'}:
            continue
        if parse_time(payload['scheduled_at']) <= current:
            candidates.append(payload)
    candidates.sort(key=lambda p: p['scheduled_at'])
    used_channels, output = set(), []
    # 5분 재시도 타이머에도 하루 채널별 한 건. 밀린 예약이 연속 발행되지 않는다.
    day = current.astimezone(__import__('social_jobs').KST).date()
    for state_path in (base / 'state').glob('*.json'):
        state = read_json(state_path, {})
        job = read_json(base / 'jobs' / state_path.name, {})
        channel = job.get('payload', {}).get('channel')
        # 응답을 잃은 게시가 실제 성공했을 수 있다. 대조 전에는 같은 채널 전체 보류.
        if state.get('phase') == 'uncertain' and channel:
            used_channels.add(channel)
        if state.get('phase') in {'published', 'published_id_unresolved'} and state.get('published_at'):
            if parse_time(state['published_at']).astimezone(__import__('social_jobs').KST).date() == day and channel:
                used_channels.add(channel)
    api = None
    if live:
        # 게시할 작업이 없는 주에도 장기 토큰은 만료 전에 갱신한다.
        api = maintain_tokens(env, api_class, base)
    verified = False
    # Mac이 꺼져 있었더라도 한 번에 채널별 한 건만. 24시간 넘은 예약은 hold.
    for payload in candidates:
        channel = payload['channel']
        if channel in used_channels:
            continue
        used_channels.add(channel)
        if not live:
            output.append({'job_id': payload['job_id'], 'mode': 'dry-run',
                           'scheduled_at': payload['scheduled_at'], 'channel': channel})
            continue
        if not verified:
            api.verify_accounts()
            verified = True
        state = execute_job(payload, api, base)
        output.append({'job_id': payload['job_id'], 'phase': state['phase'],
                       'permalink': state.get('permalink')})
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for command in ['preview', 'approve']:
        part = sub.add_parser(command)
        part.add_argument('queue')
        part.add_argument('--at', required=True, help='2026-10-13T20:30:00+09:00')
        part.add_argument('--text-file', help='사용자가 수정/선택한 최종 본문 UTF-8 파일')
        if command == 'approve':
            part.add_argument('--confirmed', action='store_true', help='본문·이미지·계정·시간에 대한 명시 승인 후에만')
            part.add_argument('--preview-sha', required=True, help='사용자가 검수한 preview_sha256')
    runner = sub.add_parser('run')
    runner.add_argument('--live', action='store_true')
    sub.add_parser('check')
    sub.add_parser('list')
    register = sub.add_parser('register-token')
    register.add_argument('channel', choices=TOKEN_KEYS)
    register.add_argument('--issued-at', required=True)
    register.add_argument('--expires-at', required=True)
    sub.add_parser('pause')
    sub.add_parser('resume')
    cancel = sub.add_parser('cancel')
    cancel.add_argument('job_id')
    args = parser.parse_args()
    try:
        # 중지 스위치는 실행 중 worker의 락을 기다리지 않는다. publish 직전 재확인한다.
        if args.command == 'pause':
            PUBLISHING.mkdir(parents=True, exist_ok=True)
            (PUBLISHING / 'PUBLISH_DISABLED').touch()
            LAUNCHD_ARMED.unlink(missing_ok=True)
            print('예약 발행 중지')
            return 0
        with lock():
            if args.command == 'resume':
                (PUBLISHING / 'PUBLISH_DISABLED').unlink(missing_ok=True)
                LAUNCHD_ARMED.parent.mkdir(parents=True, exist_ok=True)
                LAUNCHD_ARMED.touch()
                print('승인된 예약 작업만 실행 가능')
                return
            env = load_env()
            if env.get('MARKETING_EXPECTED_USERNAME', 'mu_sic_letter') != 'mu_sic_letter':
                raise ValueError('이 발행 경로는 전용 @mu_sic_letter 계정만 허용합니다.')
            if args.command == 'register-token':
                issued = int(parse_time(args.issued_at).timestamp())
                expires = int(parse_time(args.expires_at).timestamp())
                if issued > now().timestamp() or expires <= now().timestamp() or expires <= issued or expires-issued > 60*86400:
                    raise ValueError('발급/만료 시각 확인 필요. 미래 발급이나 60일 초과 만료는 등록 불가.')
                prefix = TOKEN_KEYS[args.channel]
                metadata = read_json(PUBLISHING / 'token_state.json', {})
                metadata[args.channel] = {'kind': 'long_lived_dashboard', 'issued_at': issued,
                    'expires_at': expires, 'fingerprint': token_fingerprint(env[prefix+'_ACCESS_TOKEN']),
                    'source': 'explicit_registration'}
                atomic_json(PUBLISHING / 'token_state.json', metadata)
                print(args.channel + ' 토큰 발급 정보 등록 완료')
            elif args.command in {'preview', 'approve'}:
                final = Path(args.text_file).read_text() if args.text_file else None
                source = Path(args.queue).resolve()
                preview_path = PUBLISHING / 'previews' / (source.stem + '.json')
                if args.command == 'preview':
                    payload = preview_job(args.queue, args.at, env, final)
                    preview = {'payload': payload, 'preview_sha256': digest(payload)}
                    atomic_json(preview_path, preview)
                    print(json.dumps(preview, ensure_ascii=False, indent=2))
                else:
                    if not args.confirmed:
                        raise ValueError('본문·이미지·계정·시간을 표시하고 사용자 승인을 받은 후 --confirmed를 사용하세요.')
                    preview = read_json(preview_path, {})
                    payload = preview.get('payload', {})
                    if preview.get('preview_sha256') != args.preview_sha or digest(payload) != args.preview_sha:
                        raise ValueError('사용자가 확인한 프리뷰 해시가 다릅니다. 다시 검수하세요.')
                    current_payload = payload_from_queue(args.queue, args.at,
                        env[TOKEN_KEYS[payload['channel']] + '_USER_ID'],
                        env.get('MARKETING_EXPECTED_USERNAME', 'mu_sic_letter'), final)
                    for key in ['source_sha256', 'text', 'scheduled_at', 'account_id', 'username', 'media_type', 'video_path', 'video_sha256', 'video_spec', 'share_to_feed']:
                        if payload.get(key) != current_payload.get(key):
                            raise ValueError('프리뷰 이후 큐/본문/계정/시간이 바뀌었습니다. 다시 검수하세요.')
                    if payload['channel'] == 'instagram':
                        key = 'video' if payload.get('media_type') == 'REELS' else 'image'
                        if file_digest(ROOT / payload[key + '_path']) != payload[key + '_sha256']:
                            raise ValueError('프리뷰 미디어 변경. 다시 검수하세요.')
                    payload['approved_at'] = now().isoformat()
                    saved = enqueue(payload)
                    # 작업 JSON이 정본이다. 부가 큐 표시 실패를 예약 실패로 오인하지 않는다.
                    print('예약 등록: ' + str(saved))
                    try:
                        text = source.read_text()
                        text = __import__('re').sub(r'^status: (draft|approved)$', 'status: scheduled', text, count=1, flags=__import__('re').M)
                        source.write_text(text)
                    except OSError:
                        print('WARN: 예약은 등록됐습니다. 큐 상태 표시만 실패했으니 list로 확인하고 중복 승인하지 마세요.', file=sys.stderr)
            elif args.command == 'list':
                for path in sorted((PUBLISHING / 'jobs').glob('*.json')):
                    payload = validate_job(read_json(path))
                    state = read_json(PUBLISHING / 'state' / (payload['job_id']+'.json'), {'phase':'pending'})
                    print(json.dumps({'job_id': payload['job_id'], 'channel': payload['channel'],
                        'scheduled_at': payload['scheduled_at'], 'media_type': payload.get('media_type', 'IMAGE' if payload['channel'] == 'instagram' else 'TEXT'), 'phase': state['phase']}, ensure_ascii=False))
            elif args.command == 'cancel':
                if not __import__('re').fullmatch(r'[a-z0-9][a-z0-9_-]{0,160}', args.job_id):
                    raise ValueError('잘못된 작업 ID')
                payload = validate_job(read_json(PUBLISHING / 'jobs' / (args.job_id+'.json'), {}))
                state = read_json(PUBLISHING / 'state' / (args.job_id+'.json'), {'phase':'pending'})
                if state['phase'] not in {'pending', 'container_ready', 'uploading', 'expired_hold'}:
                    raise ValueError('이미 게시됐거나 결과 미확정인 작업은 수동 확인 필요')
                state['phase'] = 'cancelled'
                save_state(PUBLISHING, payload, state)
                print('예약 취소: ' + args.job_id)
            else:
                from social_api import SocialAPI
                if args.command == 'check':
                    token_env(env, read_json(PUBLISHING / 'token_state.json', {}), int(now().timestamp()))
                    print(json.dumps(SocialAPI(env).verify_accounts(), ensure_ascii=False))
                else:
                    print(json.dumps(run_due(env, args.live, api_class=SocialAPI), ensure_ascii=False))
    except Exception as error:
        # 네트워크 라이브러리 예외에 URL/토큰이 섞일 수 있어 알 수 없는 예외 본문은 출력하지 않는다.
        safe = str(error) if isinstance(error, (ValueError, FileNotFoundError, BlockingIOError)) else type(error).__name__
        print('ERROR: ' + safe, file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
