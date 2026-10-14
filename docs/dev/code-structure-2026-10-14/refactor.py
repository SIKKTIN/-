"""One-time, token-aware extraction of current methods; preserves user edits."""
from pathlib import Path
import re
import json
import hashlib

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
TOKEN = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\n]*|(?<![\w.])\b[A-Za-z_][A-Za-z_0-9]*\b')

def members(source):
    return set(re.findall(r'^(?:@export\s+)?(?:var|const) (\w+)', source, re.M)) | set(re.findall(r'^func (\w+)', source, re.M))

def qualify(source, names, owner):
    return TOKEN.sub(lambda m: owner + '.' + m[0] if m[0] in names else m[0], source)

def methods(source):
    positions = list(re.finditer(r'^func (\w+)\([^\n]*', source, re.M))
    return {m[1]: source[m.start():positions[i+1].start() if i+1<len(positions) else len(source)] for i,m in enumerate(positions)}

paths = ['scripts/editor/map_editor.gd', 'scripts/core/escape_game.gd',
         'scripts/presentation/game_presentation.gd', 'scripts/core/game_loading.gd']
if (ROOT/'scripts/editor/map_inspector.gd').exists():
    raise SystemExit('Extraction already applied; do not overwrite snapshots or current work.')
snapshots = {}
for name in paths:
    raw = (ROOT / name).read_bytes()
    (OUT / Path(name).name).write_bytes(raw)
    snapshots[name] = {'sha256':hashlib.sha256(raw).hexdigest(), 'lines':len(raw.splitlines())}
snapshots['data/rooms/r04.json'] = {'sha256':hashlib.sha256((ROOT/'data/rooms/r04.json').read_bytes()).hexdigest()}
(OUT/'before.json').write_text(json.dumps(snapshots,indent=2),encoding='utf-8')

# Inspector owns form construction; editor continues to own commands/document.
path = ROOT / paths[0]
source = path.read_text(encoding='utf-8')
pieces = methods(source)
names = members(source)
chosen = ['clear_inspector', 'build_rotation_controls', 'build_mirror_controls',
          'build_group_inspector', 'build_selection_scope', 'refresh_inspector']
inspector = '@tool\nextends RefCounted\n\n# Form callbacks read live editor state; they never copy document/refresh flags.\nvar editor\n\nfunc _init(owner_editor) -> void:\n\teditor = owner_editor\n\n'
for name in chosen:
    header, body = pieces[name].split('\n',1)
    moved = header+'\n'+qualify(body, names, 'editor')
    # Dynamic owner calls cannot infer local declarations with := in GDScript.
    moved = re.sub(r'(?m)^(\s*var [^\n]*?):=([^\n]*editor\.[^\n]*)$', r'\1=\2', moved)
    inspector += moved
    source = source.replace(pieces[name], pieces[name].splitlines()[0]+'\n\tinspector_view.'+name+'()\n\n')
# Split the large per-object form into geometry, appearance and metadata phases.
start = inspector.index('\tfor field in ["x","y","w","h"]', inspector.index('func refresh_inspector'))
end = inspector.index('\tvar item = editor.document.value(ref)', start)
geometry = inspector[start:end]
appearance_start = end + len('\tvar item = editor.document.value(ref)\n')
appearance_end = inspector.index('\tif item is Dictionary:', appearance_start)
appearance = inspector[appearance_start:appearance_end]
details_start = appearance_end
details_end = inspector.index('\tif ref.group in ["starts","dormitories"]:', details_start)
details = inspector[details_start:details_end]
inspector = inspector[:start] + '\t_build_geometry(ref,rect)\n\tvar item = editor.document.value(ref)\n\t_build_appearance(ref,rect,item)\n\t_build_properties(ref,rect,item)\n' + inspector[details_end:]
inspector += '\nfunc _build_geometry(ref: Dictionary, rect: Rect2) -> void:\n'+geometry
inspector += '\nfunc _build_appearance(ref: Dictionary, rect: Rect2, item: Variant) -> void:\n'+appearance
inspector += '\nfunc _build_properties(ref: Dictionary, rect: Rect2, item: Variant) -> void:\n'+details
# Dispatch group-specific dictionary controls without one long nested function.
blocks = list(re.finditer(r'^\t\tif ref.group == "([^"]+)":', details, re.M))
for i, match in reversed(list(enumerate(blocks))):
    end = blocks[i+1].start() if i+1<len(blocks) else len(details)
    block = details[match.start():end]
    body = ''.join(line[2:] if line.startswith('\t\t') else line for line in block.splitlines(keepends=True)[1:])
    helper = '_build_'+match[1]
    inspector = inspector.replace(block, match[0]+'\n\t\t\t'+helper+'(ref,rect,item)\n')
    inspector += '\nfunc '+helper+'(ref: Dictionary, rect: Rect2, item: Dictionary) -> void:\n'+body
path.write_text(source.replace('var document = Document.new()', 'const InspectorView = preload("res://scripts/editor/map_inspector.gd")\nvar inspector_view = InspectorView.new(self)\nvar document = Document.new()'),encoding='utf-8')
(ROOT/'scripts/editor/map_inspector.gd').write_text(inspector,encoding='utf-8')

# Lifecycle operations preserve their authoritative ordering and public facade.
path = ROOT / paths[1]
source = path.read_text(encoding='utf-8')
pieces = methods(source)
names = members(source) | {'queue_redraw', 'get_tree'}
selected = {'reset_round':'fixed_skills,seed_value', 'load_room':'identifier,fixed_skills,seed_value',
            'capture_actor':'actor_id', 'finish_failure':'reason', 'on_actor_escaped':'actor_id'}
session = 'extends RefCounted\n\n# Stateless lifecycle coordinator. Frame/input stay in EscapeGame.\n# Service reset order is intentional: do not iterate unordered component maps.\n'
for name,args in selected.items():
    header, body = pieces[name].split('\n',1)
    signature = header.replace('func ', 'static func ',1).replace(name+'(',name+'(game, ',1)
    session += '\n'+signature+'\n'+qualify(body,names,'game').replace(',self)', ',game)')
    result = 'return ' if '-> bool' in header else ''
    source = source.replace(pieces[name],header+'\n\t'+result+'Session.'+name+'(self,'+args+')\n\n')
# Reset retains phases and relative order, but each phase has one purpose.
begin = session.index('\tif game.looting: game.looting.close()',session.index('static func reset_round'))
controls_end = session.index('\tgame.phase = "playing"',begin)
actors_end = session.index('\tif game.inventory:',controls_end)
services_end = session.index('\tif game.room_access:\n\t\tgame.room_access.tick()',actors_end)
reset_end = session.index('\nstatic func load_room', services_end)
phases = [session[begin:controls_end],session[controls_end:actors_end],session[actors_end:services_end],session[services_end:reset_end]]
session = session[:begin]+'\t_reset_controls(game)\n\t_reset_actors(game,fixed_skills,seed_value)\n\t_reset_services(game)\n\t_refresh_reset(game)\n'+session[reset_end:]
for header,body in zip(['_reset_controls(game)', '_reset_actors(game,fixed_skills: Array,seed_value: int)', '_reset_services(game)', '_refresh_reset(game)'],phases):
    session += '\nstatic func '+header+' -> void:\n'+body
path.write_text(source.replace('const Prisoner =', 'const Session = preload("res://scripts/core/game_session.gd")\nconst Prisoner =',1),encoding='utf-8')
(ROOT/'scripts/core/game_session.gd').write_text(session,encoding='utf-8')
print('Extracted inspector forms and game lifecycle, preserving facade APIs.')
