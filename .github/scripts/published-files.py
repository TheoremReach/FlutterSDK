# The files `flutter pub publish --dry-run` would publish, one path per line, from the tree it prints. A file's line
# ends with its size; a directory's doesn't.
import re
import sys

LINE = re.compile(r'^((?:[│ ]   )*)[├└]── (.+?)(?: \((<?\d+ [KMG]B)\))?$')

paths, parents = [], []
for line in open(sys.argv[1], encoding='utf-8'):
    match = LINE.match(line.rstrip('\n'))
    if not match:
        continue
    depth = len(match.group(1)) // 4
    del parents[depth:]
    if match.group(3):
        paths.append('/'.join(parents + [match.group(2)]))
    else:
        parents.append(match.group(2))
print('\n'.join(paths))
