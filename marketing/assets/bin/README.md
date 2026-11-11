# 로컬 릴스 인코더

이 Mac의 `ffmpeg`는 `imageio-ffmpeg==0.6.0` macOS arm64 wheel의 실행 파일을 같은 사용자 프로젝트로 복사한 로컬 렌더 도구다. gitignore이며 배포물/영상에 바이너리를 포함하지 않는다. 전역 Homebrew 설치는 변경하지 않는다.

다른 Mac에서는 `python3 -m pip install -r scripts/marketing/requirements-render-reel.txt`를 실행하면 렌더러가 패키지 내 FFmpeg를 사용한다. `ffmpeg`를 이 폴더에 직접 준비할 경우 신뢰할 수 있는 바이너리만 사용한다.

출처·라이선스: https://github.com/imageio/imageio-ffmpeg (wrapper BSD), 포함된 FFmpeg 빌드 라이선스는 해당 실행 파일의 `-L` 및 https://ffmpeg.org/legal.html 참조. FFmpeg 바이너리는 저장소에 커밋/재배포하지 않는다.
