"""Downloads the exact font files google_fonts uses on phones, so screenshots measure text like a real device.

Run once: python test_preview/fetch_fonts.py
Files land in test_preview/fonts/<Family>/<weight>.ttf (plus <weight>i.ttf for italics).
"""
import glob
import os
import re
import urllib.request

FAMILIES = {
    'Plus Jakarta Sans': 'plusJakartaSans',
    'Bricolage Grotesque': 'bricolageGrotesque',
    'Fraunces': 'fraunces',
    'Space Grotesk': 'spaceGrotesk',
    'Fredoka': 'fredoka',
    'Sora': 'sora',
    'Playfair Display': 'playfairDisplay',
    'DM Sans': 'dmSans',
}

cache = os.path.join(os.environ['LOCALAPPDATA'], 'Pub', 'Cache', 'hosted', 'pub.dev')
package = sorted(glob.glob(os.path.join(cache, 'google_fonts-*')))[-1]
parts = ''.join(open(path, encoding='utf-8').read() for path in glob.glob(os.path.join(package, 'lib', 'src', 'google_fonts_parts', '*.dart')))
here = os.path.dirname(os.path.abspath(__file__))

variant = re.compile(r"fontWeight: FontWeight\.w(\d+),\s*fontStyle: FontStyle\.(\w+),\s*\): const GoogleFontsFile\(\s*'([0-9a-f]+)'")
for family, method in FAMILIES.items():
    start = parts.index(f'static TextStyle {method}(')
    table = parts[start:parts.index('};', start)]
    folder = os.path.join(here, 'fonts', family)
    os.makedirs(folder, exist_ok=True)
    for weight, style, digest in variant.findall(table):
        name = os.path.join(folder, f"{weight}{'i' if style == 'italic' else ''}.ttf")
        if not os.path.exists(name):
            urllib.request.urlretrieve(f'https://fonts.gstatic.com/s/a/{digest}.ttf', name)
    print(family, len(os.listdir(folder)), 'files')
