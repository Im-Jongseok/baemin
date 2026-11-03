"""Explicit, consent-gated real inference probe; never prints API credentials."""
import argparse
import base64
import json
from pathlib import Path
import time

from .analysis import APIError, analyze
from .server import ROOT, config


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', type=Path, required=True)
    parser.add_argument('--consent', action='store_true', required=True,
                        help='Send this image to Hugging Face and the selected provider')
    parser.add_argument('--env-file', type=Path, default=ROOT / '.env')
    parser.add_argument('--max-output-tokens', type=int, default=256,
                        help='Output token limit for this single request (1–700; default: 256)')
    args = parser.parse_args()
    if not 1 <= args.max_output_tokens <= 700:
        parser.error('--max-output-tokens must be between 1 and 700')
    raw = args.image.read_bytes()
    if len(raw) > 5 * 1024 * 1024:
        parser.error('사진은 5MB 이하로 준비해 주세요.')
    mime = 'png' if raw.startswith(b'\x89PNG') else 'webp' if raw.startswith(b'RIFF') else 'jpeg'
    image = f'data:image/{mime};base64,' + base64.b64encode(raw).decode()
    settings = config(args.env_file)
    started = time.monotonic()
    try:
        result = analyze({'image': image, 'mode': 'huggingface', 'consent': args.consent},
                         token=settings['token'], model=settings['model'],
                         max_output_tokens=args.max_output_tokens)
        output = {'success': True, 'result': result}
    except APIError as error:
        output = {'success': False, 'error': error.message, 'code': error.code}
        if error.provider_status is not None:
            output['providerStatus'] = error.provider_status
    output['maxOutputTokens'] = args.max_output_tokens
    output['elapsedSeconds'] = round(time.monotonic() - started, 1)
    print(json.dumps(output, ensure_ascii=False, indent=2))
    return 0 if output['success'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
