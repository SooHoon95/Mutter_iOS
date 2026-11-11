"""승인된 소셜 작업의 고정 스냅샷과 별도 실행 상태. 비밀값은 작업 파일에 넣지 않는다."""
import contextlib
import fcntl
import hashlib
import json
import os
import re
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KST = timezone(timedelta(hours=9))
PUBLISHING = ROOT / 'marketing' / 'publishing'


def now():
    return datetime.now(timezone.utc)


def parse_time(value):
    result = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if result.tzinfo is None:
        raise ValueError('시간에는 +09:00 같은 시간대를 명시하세요.')
    return result.astimezone(timezone.utc)


def digest(data):
    return hashlib.sha256(json.dumps(data, ensure_ascii=False, sort_keys=True,
                                     separators=(',', ':')).encode()).hexdigest()


def file_digest(path, limit=45 * 1024 * 1024):
    if type(limit) is not int or not 0 < limit <= 45 * 1024 * 1024:
        raise ValueError('유효하지 않은 해시 파일 크기 제한')
    hasher = hashlib.sha256()
    total = 0
    with Path(path).open('rb') as stream:
        while True:
            chunk = stream.read(min(1024 * 1024, limit - total + 1))
            if not chunk:
                break
            total += len(chunk)
            if total > limit:
                raise ValueError('해시 검사 파일 크기 제한 초과')
            hasher.update(chunk)
    return hasher.hexdigest()


def atomic_json(path, data, mode=0o600):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix='.' + path.name)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            json.dump(data, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def read_json(path, default=None):
    path = Path(path)
    return json.loads(path.read_text()) if path.exists() else default


@contextlib.contextmanager
def lock(base=PUBLISHING):
    base.mkdir(parents=True, exist_ok=True)
    with (base / '.lock').open('a') as stream:
        fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        try:
            yield
        finally:
            fcntl.flock(stream, fcntl.LOCK_UN)


def load_env(path=ROOT / '.env.marketing'):
    path = Path(path)
    if path.stat().st_mode & 0o077:
        raise ValueError('인증 환경 파일 권한을 chmod 600으로 제한하세요.')
    values = {}
    for line in path.read_text().splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        key, separator, value = line.partition('=')
        if not separator or not re.fullmatch(r'[A-Z_][A-Z0-9_]*', key):
            raise ValueError('환경 파일은 KEY=value 형식만 지원합니다.')
        values[key] = value.strip().strip('"\'')
    return values


def update_env(pairs, path=ROOT / '.env.marketing'):
    path = Path(path)
    original = path.read_text()
    for key, value in pairs.items():
        if not re.fullmatch(r'[A-Z_][A-Z0-9_]*', key) or not value or '\n' in value or '\r' in value:
            raise ValueError('유효하지 않은 인증값')
        pattern = re.compile(r'^' + re.escape(key) + r'=.*$', re.M)
        replacement = key + '=' + value
        original = pattern.sub(lambda _: replacement, original) if pattern.search(original) else original + '\n' + replacement + '\n'
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix='.marketing-env-')
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(original)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def queue_content(path):
    path = Path(path).resolve()
    if path.parent != (ROOT / 'marketing' / 'queue').resolve():
        raise ValueError('marketing/queue/의 파일만 승인할 수 있습니다.')
    source = path.read_text()
    if not source.startswith('---\n') or '\n---\n' not in source[4:]:
        raise ValueError('큐 frontmatter가 필요합니다.')
    header, body = source[4:].split('\n---\n', 1)
    metadata = {}
    for line in header.splitlines():
        key, sep, value = line.partition(':')
        if sep:
            if key in metadata:
                raise ValueError('중복 frontmatter 키')
            metadata[key] = value.strip()
    if metadata.get('id') != path.stem:
        raise ValueError('큐 ID와 파일명이 다릅니다.')
    sections = {}
    name = None
    for line in body.splitlines():
        if line.startswith('## '):
            name = line[3:].strip()
            if name in sections:
                raise ValueError('중복 본문 섹션')
            sections[name] = []
        elif name:
            sections[name].append(line)
    return metadata, {key: '\n'.join(lines).strip() for key, lines in sections.items()}


def payload_from_queue(path, scheduled_at, account_id, username, final_text=None):
    metadata, sections = queue_content(path)
    if metadata.get('status') not in {'draft', 'approved'}:
        raise ValueError('draft/approved 상태만 예약 가능합니다.')
    kind = metadata.get('type')
    channel = {'threads': 'threads', 'instagram_card': 'instagram', 'instagram_reel': 'instagram'}.get(kind)
    if not channel:
        raise ValueError('자동 발행은 threads/instagram_card/instagram_reel만 지원합니다. 촬영용 reel_caption은 별도 영상 검수 필요.')
    if metadata.get('channel') != channel:
        raise ValueError('큐 채널과 콘텐츠 유형 불일치')
    when = parse_time(scheduled_at)
    if when <= now():
        raise ValueError('예약 시간은 미래여야 합니다. 지난 시즌/날짜는 새로 검수하세요.')
    if final_text is not None:
        text = final_text
    elif channel == 'threads':
        text = sections.get('최종') or sections.get('추천안')
    else:
        text = sections.get('캡션')
    if not text or len(text) > (500 if channel == 'threads' else 2200):
        raise ValueError('본문이 비었거나 채널 글자 수 한도를 초과했습니다.')
    if '### ' in text or '|---' in text or '<!--' in text:
        raise ValueError('촬영 설명/대안/표가 아닌 최종 본문만 승인하세요.')
    if not re.fullmatch(r'[0-9]+', account_id) or not username:
        raise ValueError('게시 대상 계정 확인 필요')
    payload = {'schema_version': 1, 'job_id': metadata['id'] + '-' + channel,
               'queue_id': metadata['id'], 'channel': channel, 'account_id': account_id,
               'username': username, 'text': text, 'scheduled_at': when.isoformat(),
               'approved_at': now().isoformat(), 'source_sha256': file_digest(path)}
    if kind == 'instagram_card':
        title, body = sections.get('카드 제목'), sections.get('카드 본문')
        if not title or not body:
            raise ValueError('카드 제목/카드 본문/캡션 섹션을 모두 작성하세요.')
        payload['card'] = {'title': title, 'body': body}
    elif kind == 'instagram_reel':
        file = metadata.get('video_file', '')
        video = (ROOT / file).resolve()
        allowed = (ROOT / 'marketing' / 'video').resolve()
        if not file or not video.is_relative_to(allowed) or video.suffix.lower() != '.mp4' or not video.is_file():
            raise ValueError('marketing/video/ 안의 로컬 MP4만 릴스 프리뷰에 사용할 수 있습니다.')
        if not 0 < video.stat().st_size <= 45 * 1024 * 1024:
            raise ValueError('릴스 파일은 로컬 제한 45 MiB 이하만 지원합니다.')
        from render_reel import validate_reel
        before = file_digest(video)
        specification = validate_reel(video)
        if file_digest(video) != before:
            raise ValueError('검수 중 영상 파일 변경. 다시 프리뷰를 만드세요.')
        payload.update(media_type='REELS', video_path=str(video.relative_to(ROOT)),
                       video_sha256=before, video_spec=specification, share_to_feed=True)
    return payload


def validate_job(job, base=PUBLISHING):
    payload = job.get('payload', {})
    approval = job.get('approval', {})
    if approval.get('confirmed') is not True or approval.get('sha256') != digest(payload):
        raise ValueError('승인 스냅샷이 변경되었습니다. 재승인 필요.')
    if payload.get('schema_version') != 1 or payload.get('channel') not in {'threads', 'instagram'}:
        raise ValueError('알 수 없는 작업 스키마')
    if not re.fullmatch(r'[a-z0-9][a-z0-9_-]{0,160}', payload.get('job_id', '')):
        raise ValueError('잘못된 작업 ID')
    parse_time(payload['scheduled_at'])
    parse_time(payload['approved_at'])
    if not re.fullmatch(r'\d+', payload.get('account_id', '')) or not payload.get('username'):
        raise ValueError('작업 계정 정보 오류')
    if not payload.get('text') or len(payload['text']) > (500 if payload['channel'] == 'threads' else 2200):
        raise ValueError('작업 본문 오류')
    if payload['channel'] == 'instagram':
        media_type = payload.get('media_type', 'IMAGE')
        if media_type not in {'IMAGE', 'REELS'}:
            raise ValueError('알 수 없는 Instagram 게시 유형')
        reel = media_type == 'REELS'
        key, extension = ('video', '.mp4') if reel else ('image', '.jpg')
        asset = (ROOT / payload[key + '_path']).resolve()
        if asset.parent != (base / 'assets').resolve() or asset.suffix.lower() != extension:
            raise ValueError('승인된 미디어 파일만 발행할 수 있습니다.')
        if not 0 < asset.stat().st_size <= (45 if reel else 8) * 1024 * 1024:
            raise ValueError('승인 미디어 파일 크기 제한 초과')
        if file_digest(asset) != payload.get(key + '_sha256'):
            raise ValueError('승인한 미디어가 변경되었습니다.')
        if reel:
            if payload.get('share_to_feed') is not True or not isinstance(payload.get('video_spec'), dict):
                raise ValueError('릴스 검수 메타데이터/피드 표시 설정이 없습니다.')

    elif payload.get('media_type', 'TEXT') != 'TEXT':
        raise ValueError('Threads는 텍스트만 지원합니다.')
    return payload
