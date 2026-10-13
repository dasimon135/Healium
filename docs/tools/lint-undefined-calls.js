// Flags called identifiers that nothing in the tree defines, excluding the ones
// upstream already calls (those are WoW APIs).  Catches a helper lost in a merge.
// Usage: node lint.js <tree-dir> [baseline-dir]
const lp = require('luaparse'), fs = require('fs'), path = require('path');

function luaFiles(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(e =>
    e.isDirectory() ? luaFiles(path.join(dir, e.name))
      : e.name.endsWith('.lua') ? [path.join(dir, e.name)] : []);
}

function scan(dir) {
  const defined = new Set(), calls = [];
  for (const f of luaFiles(dir)) {
    const ast = lp.parse(fs.readFileSync(f, 'utf8'), { luaVersion: '5.1', locations: true });
    (function walk(n) {
      if (!n || typeof n !== 'object') return;
      if (n.type === 'LocalStatement') n.variables.forEach(v => defined.add(v.name));
      if (n.type === 'FunctionDeclaration' && n.identifier && n.identifier.type === 'Identifier') defined.add(n.identifier.name);
      if (n.type === 'AssignmentStatement') n.variables.forEach(v => { if (v.type === 'Identifier') defined.add(v.name); });
      if (n.type === 'ForNumericStatement' && n.variable) defined.add(n.variable.name);
      if (n.type === 'ForGenericStatement') n.variables.forEach(v => defined.add(v.name));
      if (n.type === 'FunctionDeclaration') (n.parameters || []).forEach(p => p.name && defined.add(p.name));
      if (n.type === 'CallStatement' || n.type === 'CallExpression') {
        const base = n.base || (n.expression && n.expression.base);
        if (base && base.type === 'Identifier')
          calls.push({ name: base.name, file: path.relative(dir, f).split(path.sep).join('/'), line: base.loc.start.line });
      }
      for (const k in n) if (k !== 'loc') walk(n[k]);
    })(ast);
  }
  return { defined, calls };
}

// WoW APIs this tree calls but upstream does not, so the baseline cannot vouch for them.
const EXTRA_API = new Set(['IsInInstance', 'GetMacroIndexByName']);

const tree = scan(process.argv[2]);
const baselineUndefined = new Set();
if (process.argv[3]) {
  const base = scan(process.argv[3]);
  base.calls.forEach(c => { if (!base.defined.has(c.name)) baselineUndefined.add(c.name); });
}
const seen = new Set();
let bad = 0;
for (const c of tree.calls) {
  if (tree.defined.has(c.name) || baselineUndefined.has(c.name) || EXTRA_API.has(c.name)) continue;
  const key = c.file + ':' + c.line + ':' + c.name;
  if (seen.has(key)) continue;
  seen.add(key);
  console.log(`${c.file}:${c.line}: ${c.name}() n'est defini nulle part dans l'arbre`);
  bad++;
}
console.log(bad ? `${bad} probleme(s)` : 'aucun appel non defini');
