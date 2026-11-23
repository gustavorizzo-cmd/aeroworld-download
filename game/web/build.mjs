// Gera o jogo em UM arquivo HTML (Three.js + modelos .glb embutidos).
//   npm install && npm run build
// Saidas:
//   dist/porto_brasa.html  -> abre com dois cliques no navegador (offline)
//   dist/pagina.html       -> mesmo jogo sem <html>/<head> (para publicar como Artifact)
import { build } from 'esbuild';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const raiz = path.dirname(fileURLToPath(import.meta.url));
const dirModelos = path.join(raiz, '..', 'assets', 'modelos');
const dist = path.join(raiz, 'dist');
fs.mkdirSync(dist, { recursive: true });

const modelosEmbutidos = {
  name: 'modelos-embutidos',
  setup(b) {
    b.onResolve({ filter: /^modelos-embutidos$/ }, () => ({ path: 'modelos', namespace: 'modelos' }));
    b.onLoad({ filter: /.*/, namespace: 'modelos' }, () => {
      const dados = {};
      for (const f of fs.readdirSync(dirModelos).filter((f) => f.endsWith('.glb')).sort()) {
        dados[f.replace('.glb', '')] = fs.readFileSync(path.join(dirModelos, f)).toString('base64');
      }
      return { contents: 'export default ' + JSON.stringify(dados), loader: 'js' };
    });
  },
};

const r = await build({
  entryPoints: [path.join(raiz, 'src', 'main.js')],
  bundle: true,
  minify: true,
  format: 'iife',
  target: 'es2020',
  write: false,
  legalComments: 'none',
  plugins: [modelosEmbutidos],
});
const js = r.outputFiles[0].text.replace(/<\/script/gi, '<\\/script');
const molde = fs.readFileSync(path.join(raiz, 'src', 'pagina.html'), 'utf8');
const corpo = molde.replace('/*SCRIPT*/', () => js);

const completo = `<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
</head>
<body>
${corpo}
</body>
</html>
`;
fs.writeFileSync(path.join(dist, 'porto_brasa.html'), completo);
fs.writeFileSync(path.join(dist, 'pagina.html'), corpo);
const mb = (fs.statSync(path.join(dist, 'porto_brasa.html')).size / 1048576).toFixed(2);
console.log(`ok: dist/porto_brasa.html (${mb} MB)`);
