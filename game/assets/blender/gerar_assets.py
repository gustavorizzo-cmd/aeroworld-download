"""Gera os assets 3D low-poly de "Porto Brasa" no Blender.

Uso (Blender instalado):
    blender -b -P gerar_assets.py -- --saida ../

Uso (Blender como modulo Python, `pip install bpy`):
    python gerar_assets.py --saida ../

Opcoes:
    --saida DIR     pasta base (cria modelos/, previews/ e blender/ dentro)
    --sem-render    nao renderiza previews (bem mais rapido)

Convencoes de todos os assets:
    * Unidade: metro. Origem no chao (z = 0), centralizada.
    * Frente do asset = +Y no Blender  (vira -Z no glTF / Three.js / Godot).
    * Materiais com nome "Pintura_*" podem ser trocados no jogo para variar cor.
    * Pecas animaveis sao objetos separados (rodas, rotores, sirenes, membros).
"""

import argparse
import math
import os
import sys

import bpy  # precisa vir antes de bmesh/mathutils quando usado como modulo pip
import bmesh
from mathutils import Euler, Matrix, Vector

# --------------------------------------------------------------------------
# Argumentos
# --------------------------------------------------------------------------
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
ap = argparse.ArgumentParser()
ap.add_argument("--saida", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ap.add_argument("--sem-render", action="store_true")
ARGS = ap.parse_args(argv)
BASE = os.path.abspath(ARGS.saida)
DIR_MODELOS = os.path.join(BASE, "modelos")
DIR_PREVIEWS = os.path.join(BASE, "previews")
DIR_BLEND = os.path.join(BASE, "blender")
for d in (DIR_MODELOS, DIR_PREVIEWS, DIR_BLEND):
    os.makedirs(d, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
SCENE = bpy.context.scene
SCENE.name = "Assets"
pi = math.pi
rad = math.radians

# --------------------------------------------------------------------------
# Materiais
# --------------------------------------------------------------------------
_MATS = {}


def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcor(h):
    h = h.lstrip("#")
    return tuple(_lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (1.0,)


def mat(nome, cor, rough=0.7, metal=0.0, emit=None, forca=3.0):
    if nome in _MATS:
        return _MATS[nome]
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = hexcor(cor)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit:
        p.inputs["Emission Color"].default_value = hexcor(emit)
        p.inputs["Emission Strength"].default_value = forca
    m.diffuse_color = hexcor(cor)
    _MATS[nome] = m
    return m


# Paleta comum
PNEU = mat("Pneu", "#1b1b1d", 0.9)
ARO = mat("Aro", "#a7adb3", 0.35, 0.8)
VIDRO = mat("Vidro_Carro", "#1c2836", 0.12, 0.4)
PLASTICO = mat("Plastico_Escuro", "#2a2b2e", 0.6)
FAROL = mat("Farol", "#fff4d6", 0.3, emit="#fff1c9", forca=4)
LANTERNA = mat("Lanterna", "#b3131b", 0.3, emit="#ff2020", forca=3)
CROMO = mat("Cromado", "#d9dde1", 0.2, 1.0)
BRANCO = mat("Branco", "#f1f1ee", 0.55)
PRETO = mat("Preto", "#131518", 0.55)
SIRENE_VERM = mat("Sirene_Vermelha", "#d01818", 0.3, emit="#ff1a1a", forca=6)
SIRENE_AZUL = mat("Sirene_Azul", "#1636d6", 0.3, emit="#1f4dff", forca=6)
PELE = mat("Pele", "#c48a5f", 0.65)
CABELO = mat("Cabelo", "#24180f", 0.8)
OLHO = mat("Olho", "#141414", 0.4)
LARANJA = mat("Laranja_Sinal", "#ff6a13", 0.55)
VERMELHO = mat("Vermelho_Sinal", "#c8211b", 0.55)
METAL = mat("Metal", "#80868c", 0.4, 0.8)
METAL_ESC = mat("Metal_Escuro", "#3b3f44", 0.45, 0.7)
CONCRETO = mat("Concreto", "#bdb6aa", 0.85)
CONCRETO_ESC = mat("Concreto_Escuro", "#8e877d", 0.85)
VIDRO_PREDIO = mat("Vidro_Predio", "#46739c", 0.12, 0.6)
VIDRO_LOJA = mat("Vidro_Loja", "#2c4a63", 0.08, 0.3)
MADEIRA = mat("Madeira", "#7a4e2d", 0.8)
TELHA = mat("Telha", "#b5523b", 0.8)
ASFALTO = mat("Asfalto", "#38383b", 0.95)
FAIXA_BRANCA = mat("Faixa_Branca", "#ececec", 0.7)
FAIXA_AMARELA = mat("Faixa_Amarela", "#f2c230", 0.7)
CALCADA = mat("Calcada", "#bcb6aa", 0.9)
MEIO_FIO = mat("Meio_Fio", "#8f8a82", 0.9)
TRONCO = mat("Tronco_Palmeira", "#8a6a45", 0.9)
FOLHA = mat("Folha", "#3f8f3a", 0.7)
FOLHA_ESC = mat("Folha_Escura", "#2f6f2c", 0.7)
COCO = mat("Coco", "#5b3f22", 0.8)
LUZ_POSTE = mat("Luz_Poste", "#fff3cf", 0.3, emit="#ffe3a3", forca=5)
LUZ_VERMELHA = mat("Luz_Vermelha", "#c01010", 0.3, emit="#ff2a1a", forca=5)
LUZ_AMARELA = mat("Luz_Amarela", "#c08a10", 0.3, emit="#ffb31a", forca=1.5)
LUZ_VERDE = mat("Luz_Verde", "#0f8a2e", 0.3, emit="#1aff5a", forca=1.5)
LUZ_ALERTA = mat("Luz_Alerta", "#ff8a1a", 0.3, emit="#ff9a2a", forca=4)

# --------------------------------------------------------------------------
# Construtor de malha (tudo em bmesh, sem bpy.ops)
# --------------------------------------------------------------------------
CUR = {"coll": None}


def _m(loc=(0, 0, 0), rot=(0, 0, 0), escala=(1, 1, 1)):
    S = Matrix.Diagonal(Vector((*escala, 1.0)))
    return Matrix.Translation(Vector(loc)) @ Euler(rot, "XYZ").to_matrix().to_4x4() @ S


class Malha:
    def __init__(self, nome):
        self.nome = nome
        self.bm = bmesh.new()
        self.mats = []

    def _idx(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def _pintar(self, faces, m, liso=False):
        i = self._idx(m)
        for f in faces:
            f.material_index = i
            f.smooth = liso

    def _faces(self, verts):
        return list({f for v in verts for f in v.link_faces})

    def caixa(self, tam, loc, m, bisel=0.0, rot=(0, 0, 0)):
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=_m(loc, rot, tam))
        verts = r["verts"]
        self._pintar(self._faces(verts), m)
        if bisel > 0:
            arestas = list({e for v in verts for e in v.link_edges})
            b = bmesh.ops.bevel(self.bm, geom=arestas, offset=bisel, segments=1,
                                affect="EDGES", profile=0.5, clamp_overlap=True)
            self._pintar(b["faces"], m)
        return self

    def cilindro(self, r1, r2, alt, loc, m, seg=12, rot=(0, 0, 0), liso=False):
        r = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg,
                                  radius1=r1, radius2=r2, depth=alt, matrix=_m(loc, rot))
        self._pintar(self._faces(r["verts"]), m, liso)
        return self

    def esfera(self, raio, loc, m, escala=(1, 1, 1), seg=10, aneis=7, liso=True, rot=(0, 0, 0)):
        r = bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=aneis, radius=raio,
                                      matrix=_m(loc, rot, escala))
        self._pintar(self._faces(r["verts"]), m, liso)
        return self

    def casco(self, pontos, faces, m):
        vs = [self.bm.verts.new(p) for p in pontos]
        fs = [self.bm.faces.new([vs[i] for i in f]) for f in faces]
        self._pintar(fs, m)
        return self

    def prisma(self, baixo, cima, m):
        """Solido de 8 vertices: 4 de baixo + 4 de cima (mesma ordem)."""
        return self.casco(list(baixo) + list(cima),
                          [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2),
                           (2, 6, 7, 3), (3, 7, 4, 0)], m)

    def objeto(self, pai=None, loc=(0, 0, 0), rot=(0, 0, 0)):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        me = bpy.data.meshes.new(self.nome)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        nome = self.nome if self.nome not in bpy.data.objects else self.nome + "_corpo"
        ob = bpy.data.objects.new(nome, me)
        CUR["coll"].objects.link(ob)
        ob.parent = pai
        ob.location = loc
        ob.rotation_euler = rot
        return ob


def texto(txt, tam, loc, rot, m, pai, nome, extrusao=0.015):
    cu = bpy.data.curves.new(nome, "FONT")
    cu.body = txt
    cu.size = tam
    cu.extrude = extrusao
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    tmp = bpy.data.objects.new(nome + "_tmp", cu)
    CUR["coll"].objects.link(tmp)
    bpy.context.view_layer.update()
    ev = tmp.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = bpy.data.meshes.new_from_object(ev)
    bpy.data.objects.remove(tmp)
    bpy.data.curves.remove(cu)
    me.materials.clear()
    me.materials.append(m)
    ob = bpy.data.objects.new(nome, me)
    CUR["coll"].objects.link(ob)
    ob.parent = pai
    ob.location = loc
    ob.rotation_euler = rot
    return ob


# Rotacoes de placas de texto (texto nasce deitado olhando para +Z)
OLHA_MAIS_Y = (pi / 2, 0, pi)
OLHA_MENOS_Y = (pi / 2, 0, 0)
OLHA_MAIS_X = (pi / 2, 0, pi / 2)
OLHA_MENOS_X = (pi / 2, 0, -pi / 2)

# --------------------------------------------------------------------------
# Registro de assets
# --------------------------------------------------------------------------
CATEGORIAS = ["veiculos", "personagens", "props", "predios", "ruas"]
ASSETS = []  # (categoria, nome, funcao, descricao)
_cat_coll = {}


def asset(categoria, descricao):
    def deco(fn):
        ASSETS.append((categoria, fn.__name__, fn, descricao))
        return fn
    return deco


def novo_asset(categoria, nome, descricao):
    if categoria not in _cat_coll:
        c = bpy.data.collections.new(categoria)
        SCENE.collection.children.link(c)
        _cat_coll[categoria] = c
    coll = bpy.data.collections.new(nome)
    _cat_coll[categoria].children.link(coll)
    CUR["coll"] = coll
    raiz = bpy.data.objects.new(nome, None)
    raiz.empty_display_type = "PLAIN_AXES"
    raiz["categoria"] = categoria
    raiz["descricao"] = descricao
    coll.objects.link(raiz)
    return coll, raiz


# ==========================================================================
# VEICULOS
# ==========================================================================
def roda(nome, raio, larg, pai, loc):
    w = Malha(nome)
    w.cilindro(raio, raio, larg, (0, 0, 0), PNEU, seg=14, rot=(0, pi / 2, 0))
    w.cilindro(raio * 0.58, raio * 0.58, larg + 0.02, (0, 0, 0), ARO, seg=10, rot=(0, pi / 2, 0))
    w.objeto(pai, loc)


def carro(raiz, nome, pintura, L=4.4, W=1.8, z0=0.32, z1=0.88,
          cab=(-1.05, 0.95, -0.75, 0.35, 1.38, 1.38), teto=None, raio=0.36, eixo=1.35):
    b = Malha(nome + "_carroceria")
    b.caixa((W, L, z1 - z0), (0, 0, (z0 + z1) / 2), pintura, bisel=0.08)
    yb0, yb1, yt0, yt1, zt, wt = cab
    wb = W - 0.14
    baixo = [(-wb / 2, yb0, z1), (wb / 2, yb0, z1), (wb / 2, yb1, z1), (-wb / 2, yb1, z1)]
    cima = [(-wt / 2, yt0, zt), (wt / 2, yt0, zt), (wt / 2, yt1, zt), (-wt / 2, yt1, zt)]
    b.prisma(baixo, cima, VIDRO)
    # coluna central (coluna B) na cor da carroceria
    ym = (max(yb0, yt0) + min(yb1, yt1)) / 2
    e = 0.012
    b.prisma([(-wb / 2 - e, ym - 0.08, z1), (wb / 2 + e, ym - 0.08, z1), (wb / 2 + e, ym + 0.08, z1), (-wb / 2 - e, ym + 0.08, z1)],
             [(-wt / 2 - e, ym - 0.08, zt), (wt / 2 + e, ym - 0.08, zt), (wt / 2 + e, ym + 0.08, zt), (-wt / 2 - e, ym + 0.08, zt)],
             pintura)
    b.caixa((wt + 0.05, yt1 - yt0 + 0.05, 0.06), (0, (yt0 + yt1) / 2, zt + 0.02), teto or pintura, bisel=0.02)
    # para-choques, grade, farois, lanternas, retrovisores
    b.caixa((W - 0.06, 0.14, 0.18), (0, L / 2 + 0.01, z0 + 0.1), PLASTICO, bisel=0.03)
    b.caixa((W - 0.06, 0.14, 0.18), (0, -L / 2 - 0.01, z0 + 0.1), PLASTICO, bisel=0.03)
    b.caixa((0.62, 0.04, 0.13), (0, L / 2 + 0.005, z0 + 0.32), PLASTICO)
    for s in (-1, 1):
        b.caixa((0.34, 0.05, 0.12), (s * (W / 2 - 0.3), L / 2 + 0.005, z0 + 0.34), FAROL)
        b.caixa((0.34, 0.05, 0.11), (s * (W / 2 - 0.3), -L / 2 - 0.005, z0 + 0.36), LANTERNA)
        b.caixa((0.08, 0.16, 0.1), (s * (W / 2 + 0.03), yb1 - 0.18, z1 + 0.1), pintura, bisel=0.02)
    ob = b.objeto(raiz)
    for nome_r, sx, sy in (("roda_diant_esq", -1, 1), ("roda_diant_dir", 1, 1),
                           ("roda_tras_esq", -1, -1), ("roda_tras_dir", 1, -1)):
        roda(nome_r, raio, 0.26, raiz, (sx * (W / 2 - 0.1), sy * eixo, raio))
    return ob


@asset("veiculos", "Sedan civil comum. Material Pintura_Sedan troca a cor.")
def carro_sedan(raiz):
    carro(raiz, "sedan", mat("Pintura_Sedan", "#2f6db5", 0.35, 0.3))


@asset("veiculos", "Esportivo da Orla, baixo e largo, com aerofolio.")
def carro_esportivo(raiz):
    p = mat("Pintura_Esportivo", "#d7261e", 0.25, 0.4)
    carro(raiz, "esportivo", p, L=4.5, W=1.95, z0=0.22, z1=0.68,
          cab=(-1.25, 0.55, -0.9, -0.05, 1.1, 1.3), raio=0.34, eixo=1.45)
    a = Malha("aerofolio")
    for s in (-1, 1):
        a.caixa((0.06, 0.12, 0.22), (s * 0.6, -2.0, 0.78), PRETO)
    a.caixa((1.7, 0.32, 0.04), (0, -2.05, 0.9), PRETO, rot=(rad(-6), 0, 0))
    a.objeto(raiz)


@asset("veiculos", "Viatura da policia de Porto Brasa. Objetos sirene_* piscam no jogo.")
def viatura_policia(raiz):
    W, L, z0, z1 = 1.8, 4.4, 0.32, 0.88
    carro(raiz, "viatura", mat("Pintura_Viatura", "#111418", 0.4, 0.3), teto=BRANCO)
    d = Malha("viatura_faixas")
    d.caixa((W + 0.025, 2.0, 0.34), (0, -0.05, 0.62), BRANCO, bisel=0.02)
    d.caixa((W - 0.1, 0.22, 0.24), (0, L / 2 + 0.12, 0.5), PRETO)  # para-choque de impulsao
    d.caixa((1.2, 0.32, 0.07), (0, -0.2, 1.47), PLASTICO, bisel=0.01)  # base do giroflex
    d.objeto(raiz)
    sv = Malha("sirene_vermelha")
    sv.caixa((0.5, 0.26, 0.12), (0, 0, 0), SIRENE_VERM, bisel=0.02)
    sv.objeto(raiz, (-0.3, -0.2, 1.56))
    sa = Malha("sirene_azul")
    sa.caixa((0.5, 0.26, 0.12), (0, 0, 0), SIRENE_AZUL, bisel=0.02)
    sa.objeto(raiz, (0.3, -0.2, 1.56))
    texto("POLÍCIA", 0.26, (W / 2 + 0.03, -0.05, 0.62), OLHA_MAIS_X, PRETO, raiz, "texto_policia_dir")
    texto("POLÍCIA", 0.26, (-W / 2 - 0.03, -0.05, 0.62), OLHA_MENOS_X, PRETO, raiz, "texto_policia_esq")


@asset("veiculos", "Helicoptero da policia (4 estrelas). rotor_principal e rotor_cauda giram.")
def helicoptero_policia(raiz):
    azul = mat("Pintura_Helicoptero", "#1d2f5c", 0.35, 0.3)
    c = Malha("helicoptero_corpo")
    c.esfera(1.0, (0, 0.4, 1.55), azul, escala=(1.25, 2.0, 1.1), seg=14, aneis=9)
    c.esfera(1.0, (0, 1.25, 1.6), VIDRO, escala=(1.05, 1.15, 0.85), seg=14, aneis=9)
    c.caixa((2.52, 2.2, 0.28), (0, 0.2, 1.3), BRANCO, bisel=0.05)
    c.cilindro(0.14, 0.34, 4.6, (0, -3.1, 1.85), azul, seg=10, rot=(-pi / 2, 0, 0))
    c.caixa((0.09, 0.8, 1.1), (0, -5.25, 2.3), azul, bisel=0.03, rot=(rad(-18), 0, 0))
    c.caixa((1.5, 0.38, 0.06), (0, -4.6, 1.95), azul)
    c.caixa((1.0, 1.9, 0.5), (0, -0.1, 2.75), METAL_ESC, bisel=0.12)
    c.cilindro(0.09, 0.09, 0.4, (0, 0, 3.15), METAL)
    for s in (-1, 1):
        c.cilindro(0.055, 0.055, 3.4, (s * 0.95, 0.3, 0.06), METAL, seg=8, rot=(pi / 2, 0, 0))
        for y in (-0.6, 1.2):
            c.caixa((0.07, 0.09, 1.0), (s * 0.85, y, 0.55), METAL, rot=(0, s * rad(-12), 0))
    c.objeto(raiz)
    texto("POLÍCIA", 0.3, (0.32, -2.3, 1.85), OLHA_MAIS_X, BRANCO, raiz, "texto_policia_dir")
    texto("POLÍCIA", 0.3, (-0.32, -2.3, 1.85), OLHA_MENOS_X, BRANCO, raiz, "texto_policia_esq")
    h = Malha("holofote")
    h.cilindro(0.16, 0.16, 0.22, (0, 0, 0), METAL_ESC, seg=10, rot=(rad(-60), 0, 0))
    h.cilindro(0.13, 0.13, 0.04, (0, 0.1, -0.06), FAROL, seg=10, rot=(rad(-60), 0, 0))
    h.objeto(raiz, (0, 1.75, 0.75))
    r = Malha("rotor_principal")
    r.cilindro(0.22, 0.22, 0.18, (0, 0, 0), METAL_ESC)
    for k in range(4):
        t = k * pi / 2
        r.caixa((0.32, 5.0, 0.04), (-2.6 * math.sin(t), 2.6 * math.cos(t), 0), PRETO, rot=(0, 0, t))
    r.objeto(raiz, (0, 0, 3.38))
    rc = Malha("rotor_cauda")
    rc.caixa((0.04, 0.13, 1.25), (0, 0, 0), PRETO)
    rc.caixa((0.04, 1.25, 0.13), (0, 0, 0), PRETO)
    rc.cilindro(0.07, 0.07, 0.12, (0, 0, 0), METAL, seg=8, rot=(0, pi / 2, 0))
    rc.objeto(raiz, (0.12, -5.3, 2.35))


# ==========================================================================
# PERSONAGENS (membros separados, pivo nas articulacoes)
# ==========================================================================
def humano(raiz, camisa, calca, sapato, policial=False):
    """Corpo com articulacoes para animacao fluida.

    Hierarquia (pivos nas articulacoes):
      raiz -> tronco (quadril) -> cabeca (pescoco)
                               -> braco_esq/dir (ombro) -> antebraco_esq/dir (cotovelo)
           -> perna_esq/dir (quadril) -> canela_esq/dir (joelho)
    """
    manga = camisa
    pele_braco = camisa if policial else PELE
    # pernas: coxa + joelho, canela + sapato
    for lado, s in (("esq", -1), ("dir", 1)):
        p = Malha("perna_" + lado)
        p.cilindro(0.068, 0.085, 0.46, (0, 0, -0.22), calca, seg=10, liso=True)
        p.esfera(0.066, (0, 0, -0.45), calca, seg=10, aneis=6)
        coxa = p.objeto(raiz, (s * 0.1, 0, 0.95))
        c = Malha("canela_" + lado)
        c.cilindro(0.05, 0.064, 0.42, (0, 0, -0.21), calca, seg=10, liso=True)
        c.caixa((0.1, 0.25, 0.08), (0, 0.05, -0.46), sapato, bisel=0.03)
        c.objeto(coxa, (0, 0, -0.45))
    # tronco: quadril, cintura mais fina, ombros largos
    t = Malha("tronco")
    t.prisma([(-0.17, -0.11, -0.06), (0.17, -0.11, -0.06), (0.17, 0.11, -0.06), (-0.17, 0.11, -0.06)],
             [(-0.18, -0.115, 0.12), (0.18, -0.115, 0.12), (0.18, 0.115, 0.12), (-0.18, 0.115, 0.12)],
             PRETO if policial else calca)
    t.prisma([(-0.175, -0.11, 0.1), (0.175, -0.11, 0.1), (0.175, 0.11, 0.1), (-0.175, 0.11, 0.1)],
             [(-0.235, -0.125, 0.58), (0.235, -0.125, 0.58), (0.235, 0.125, 0.58), (-0.235, 0.125, 0.58)],
             camisa)
    for s in (-1, 1):
        t.esfera(0.085, (s * 0.235, 0, 0.545), camisa, seg=10, aneis=6)
    t.cilindro(0.052, 0.056, 0.12, (0, 0, 0.635), PELE, seg=10, liso=True)
    if policial:
        t.prisma([(-0.195, -0.135, 0.2), (0.195, -0.135, 0.2), (0.195, 0.135, 0.2), (-0.195, 0.135, 0.2)],
                 [(-0.235, -0.14, 0.55), (0.235, -0.14, 0.55), (0.235, 0.14, 0.55), (-0.235, 0.14, 0.55)],
                 PRETO)
        t.caixa((0.07, 0.02, 0.08), (0.11, 0.145, 0.45), mat("Distintivo", "#d6b33c", 0.3, 0.9))
    tronco = t.objeto(raiz, (0, 0, 0.95))
    # cabeca
    h = Malha("cabeca")
    h.caixa((0.21, 0.24, 0.26), (0, 0.005, 0.135), PELE, bisel=0.07)
    for s in (-1, 1):
        h.caixa((0.035, 0.015, 0.03), (s * 0.052, 0.125, 0.16), OLHO)
        h.caixa((0.06, 0.012, 0.012), (s * 0.055, 0.124, 0.192), CABELO)
        h.caixa((0.025, 0.05, 0.07), (s * 0.108, 0.0, 0.13), PELE, bisel=0.01)
    h.caixa((0.035, 0.04, 0.06), (0, 0.135, 0.12), PELE, bisel=0.01)
    h.caixa((0.07, 0.012, 0.014), (0, 0.123, 0.07), mat("Boca", "#7a3b2e", 0.6))
    if policial:
        q = mat("Quepe", "#1a2747", 0.6)
        h.cilindro(0.135, 0.14, 0.1, (0, 0, 0.29), q, seg=14, liso=True)
        h.caixa((0.2, 0.11, 0.02), (0, 0.15, 0.245), PRETO)
    else:
        h.caixa((0.23, 0.26, 0.07), (0, -0.005, 0.27), CABELO, bisel=0.03)
        h.caixa((0.23, 0.06, 0.17), (0, -0.115, 0.2), CABELO, bisel=0.02)
    h.objeto(tronco, (0, 0, 0.68))
    # bracos: braco (manga) + cotovelo, antebraco + mao
    for lado, s in (("esq", -1), ("dir", 1)):
        a = Malha("braco_" + lado)
        if policial:
            a.cilindro(0.05, 0.062, 0.29, (0, 0, -0.145), manga, seg=10, liso=True)
        else:
            a.cilindro(0.064, 0.07, 0.15, (0, 0, -0.07), manga, seg=10, liso=True)
            a.cilindro(0.048, 0.054, 0.16, (0, 0, -0.21), PELE, seg=10, liso=True)
        a.esfera(0.049, (0, 0, -0.29), pele_braco, seg=10, aneis=6)
        braco = a.objeto(tronco, (s * 0.255, 0, 0.53))
        f = Malha("antebraco_" + lado)
        f.cilindro(0.04, 0.048, 0.26, (0, 0, -0.13), pele_braco, seg=10, liso=True)
        f.caixa((0.055, 0.085, 0.1), (0, 0.005, -0.31), PELE, bisel=0.02)
        f.objeto(braco, (0, 0, -0.29))


@asset("personagens", "Protagonista. Roupa_Camisa/Roupa_Calca trocam o visual (reduz a Ficha).")
def protagonista(raiz):
    humano(raiz, mat("Roupa_Camisa", "#e2553a", 0.8), mat("Roupa_Calca", "#2d3a55", 0.85),
           mat("Roupa_Sapato", "#e9e6df", 0.7))


@asset("personagens", "Policial de patrulha com colete e quepe.")
def policial(raiz):
    farda = mat("Farda", "#28406e", 0.8)
    humano(raiz, farda, farda, PRETO, policial=True)


# ==========================================================================
# PROPS
# ==========================================================================
@asset("props", "Cone de transito.")
def cone(raiz):
    b = Malha("cone")
    b.caixa((0.4, 0.4, 0.03), (0, 0, 0.015), LARANJA, bisel=0.01)
    b.cilindro(0.15, 0.03, 0.7, (0, 0, 0.38), LARANJA, seg=12)
    b.cilindro(0.094, 0.073, 0.12, (0, 0, 0.45), BRANCO, seg=12)
    b.objeto(raiz)


@asset("props", "Cavalete de bloqueio policial (3 estrelas). luz_alerta pisca.")
def barreira(raiz):
    b = Malha("barreira")
    for x in (-1.1, 1.1):
        for s in (-1, 1):
            b.caixa((0.06, 0.06, 1.1), (x, s * 0.13, 0.52), METAL_ESC, rot=(s * rad(14), 0, 0))
    n = 8
    larg = 2.5 / n
    for i in range(n):
        x = -1.25 + larg * (i + 0.5)
        for z, off in ((0.85, 0), (0.52, 1)):
            b.caixa((larg, 0.05, 0.2), (x, 0, z), VERMELHO if (i + off) % 2 == 0 else BRANCO)
    b.objeto(raiz)
    l = Malha("luz_alerta")
    l.cilindro(0.07, 0.07, 0.1, (0, 0, 0), LUZ_ALERTA, seg=10)
    l.objeto(raiz, (1.1, 0, 1.0))


@asset("props", "Tapete de pregos que fura pneus.")
def tapete_pregos(raiz):
    b = Malha("tapete_pregos")
    for i in range(6):
        b.caixa((0.47, 0.22, 0.03), (-1.25 + i * 0.5, 0, 0.015), METAL_ESC)
    for i in range(15):
        for y in (-0.06, 0.06):
            b.cilindro(0.025, 0.002, 0.09, (-1.4 + i * 0.2, y, 0.075), METAL, seg=4)
    b.objeto(raiz)


@asset("props", "Poste de luz. O braco aponta para +Y (rua). Material Luz_Poste acende a noite.")
def poste(raiz):
    b = Malha("poste")
    b.cilindro(0.16, 0.16, 0.4, (0, 0, 0.2), CONCRETO_ESC, seg=8)
    b.cilindro(0.075, 0.05, 7.0, (0, 0, 3.7), METAL, seg=8)
    b.caixa((0.07, 1.6, 0.07), (0, 0.8, 7.1), METAL)
    b.caixa((0.36, 0.62, 0.14), (0, 1.55, 7.05), METAL_ESC, bisel=0.03)
    b.caixa((0.28, 0.5, 0.03), (0, 1.55, 6.97), LUZ_POSTE)
    b.objeto(raiz)


@asset("props", "Semaforo. Objetos luz_vermelha/amarela/verde ligam e desligam.")
def semaforo(raiz):
    b = Malha("semaforo")
    b.cilindro(0.07, 0.06, 3.4, (0, 0, 1.7), METAL_ESC, seg=8)
    b.caixa((0.34, 0.26, 0.95), (0, 0.1, 3.0), PRETO, bisel=0.03)
    for z in (3.28, 3.0, 2.72):
        b.caixa((0.26, 0.14, 0.04), (0, 0.27, z + 0.12), PRETO)
    b.objeto(raiz)
    for nome, z, m in (("luz_vermelha", 3.28, LUZ_VERMELHA), ("luz_amarela", 3.0, LUZ_AMARELA),
                       ("luz_verde", 2.72, LUZ_VERDE)):
        l = Malha(nome)
        l.cilindro(0.1, 0.1, 0.04, (0, 0, 0), m, seg=12, rot=(pi / 2, 0, 0))
        l.objeto(raiz, (0, 0.235, z))


@asset("props", "Camera de seguranca (CCTV) de parede. Destruir apaga a evidencia 'camera'.")
def camera_cctv(raiz):
    corpo = mat("Camera_Corpo", "#d8d8d4", 0.5)
    b = Malha("camera_cctv")
    b.caixa((0.16, 0.04, 0.16), (0, 0.02, 0), corpo)
    b.caixa((0.06, 0.25, 0.06), (0, 0.15, 0), corpo)
    b.caixa((0.15, 0.36, 0.15), (0, 0.33, -0.08), corpo, bisel=0.03, rot=(rad(-20), 0, 0))
    b.cilindro(0.05, 0.05, 0.04, (0, 0.52, -0.15), PRETO, seg=10, rot=(pi / 2 - rad(20), 0, 0))
    b.objeto(raiz)
    l = Malha("led")
    l.caixa((0.025, 0.025, 0.025), (0, 0, 0), SIRENE_VERM)
    l.objeto(raiz, (0.05, 0.49, -0.07))


@asset("props", "Palmeira da orla (tronco curvo, 7 m).")
def palmeira(raiz):
    b = Malha("palmeira")
    segs, h = 8, 0.9
    dx = lambda z: 0.012 * z * z
    for i in range(segs):
        zc = (i + 0.5) * h
        r = 0.22 - 0.01 * i
        b.cilindro(r, r - 0.02, h * 1.02, (dx(zc), 0, zc), TRONCO, seg=7,
                   rot=(0, math.atan(0.024 * zc), 0))
    topo = Vector((dx(segs * h), 0, segs * h))
    for k in range(8):
        a = k * pi / 4 + 0.2
        d = Vector((math.cos(a), math.sin(a), 0))
        th = a - pi / 2
        m = FOLHA if k % 2 == 0 else FOLHA_ESC
        t1, t2 = rad(18), rad(-38)
        c1 = topo + d * 0.8 * math.cos(t1) + Vector((0, 0, 0.8 * math.sin(t1)))
        f1 = topo + d * 1.6 * math.cos(t1) + Vector((0, 0, 1.6 * math.sin(t1)))
        c2 = f1 + d * 0.75 * math.cos(t2) + Vector((0, 0, 0.75 * math.sin(t2)))
        b.caixa((0.55, 1.6, 0.03), c1, m, rot=(t1, 0, th))
        b.caixa((0.42, 1.5, 0.03), c2, m, rot=(t2, 0, th))
    for k in range(3):
        a = k * 2 * pi / 3
        b.esfera(0.13, topo + Vector((0.2 * math.cos(a), 0.2 * math.sin(a), -0.2)), COCO, seg=8, aneis=6)
    b.objeto(raiz)


@asset("props", "Lixeira de calcada.")
def lixeira(raiz):
    verde = mat("Lixeira_Verde", "#2f7a46", 0.6)
    b = Malha("lixeira")
    b.cilindro(0.24, 0.27, 0.85, (0, 0, 0.425), verde, seg=12)
    b.cilindro(0.29, 0.29, 0.06, (0, 0, 0.88), METAL_ESC, seg=12)
    b.objeto(raiz)


@asset("props", "Hidrante.")
def hidrante(raiz):
    b = Malha("hidrante")
    b.cilindro(0.16, 0.16, 0.06, (0, 0, 0.03), VERMELHO, seg=10)
    b.cilindro(0.11, 0.11, 0.55, (0, 0, 0.33), VERMELHO, seg=10)
    b.esfera(0.12, (0, 0, 0.62), VERMELHO, seg=10, aneis=6)
    b.cilindro(0.045, 0.045, 0.34, (0, 0, 0.42), METAL, seg=8, rot=(0, pi / 2, 0))
    b.cilindro(0.055, 0.055, 0.2, (0, 0.1, 0.42), METAL, seg=8, rot=(pi / 2, 0, 0))
    b.objeto(raiz)


@asset("props", "Conteiner maritimo de 20 pes (porto). Pintura_Conteiner troca a cor.")
def conteiner(raiz):
    p = mat("Pintura_Conteiner", "#1f5f8b", 0.6, 0.3)
    L, W, H = 6.06, 2.44, 2.59
    b = Malha("conteiner")
    b.caixa((W, L, H - 0.1), (0, 0, H / 2 + 0.05), p)
    b.caixa((W + 0.04, L + 0.04, 0.12), (0, 0, 0.06), METAL_ESC)
    b.caixa((W + 0.04, L + 0.04, 0.08), (0, 0, H - 0.04), p)
    n = 19
    for i in range(n):
        y = -L / 2 + 0.25 + i * (L - 0.5) / (n - 1)
        for s in (-1, 1):
            b.caixa((0.04, 0.12, H - 0.25), (s * (W / 2 + 0.01), y, H / 2), p)
    for x in (-0.8, -0.35, 0.35, 0.8):
        b.cilindro(0.025, 0.025, H - 0.3, (x, -L / 2 - 0.05, H / 2), METAL, seg=6)
    b.caixa((0.02, 0.04, H - 0.3), (0, -L / 2 - 0.02, H / 2), METAL_ESC)
    b.objeto(raiz)


# ==========================================================================
# PREDIOS
# ==========================================================================
@asset("predios", "Torre comercial do Centro (12 andares, ~42 m). Alvo do golpe do banco.")
def predio_centro(raiz):
    A, andares, h = 14.0, 12, 3.4
    H = andares * h
    b = Malha("predio_centro")
    b.caixa((A + 0.8, A + 0.8, 0.3), (0, 0, 0.15), CONCRETO_ESC)
    b.caixa((A - 1.4, A - 1.4, h), (0, 0, 0.3 + h / 2), VIDRO_LOJA)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.caixa((1.0, 1.0, h), (sx * (A / 2 - 0.5), sy * (A / 2 - 0.5), 0.3 + h / 2), CONCRETO)
    b.caixa((A - 0.4, A - 0.4, H - h), (0, 0, 0.3 + h + (H - h) / 2), CONCRETO)
    for f in range(1, andares):
        b.caixa((A - 0.2, A - 0.2, 2.2), (0, 0, 0.3 + f * h + 1.6), VIDRO_PREDIO)
    for k in range(6):
        p = -A / 2 + 1.2 + k * (A - 2.4) / 5
        for (x, y, sx, sy) in ((p, A / 2, 0.3, 0.3), (p, -A / 2, 0.3, 0.3),
                               (A / 2, p, 0.3, 0.3), (-A / 2, p, 0.3, 0.3)):
            b.caixa((sx, sy, H - h), (x, y, 0.3 + h + (H - h) / 2), CONCRETO)
    b.caixa((A + 0.2, A + 0.2, 0.6), (0, 0, 0.3 + H + 0.3), CONCRETO_ESC)
    for (x, y) in ((-3, -2), (2.5, 3), (3.5, -3.5)):
        b.caixa((2.2, 1.6, 1.2), (x, y, 0.3 + H + 1.2), METAL)
    b.cilindro(0.08, 0.05, 7, (-4.5, 4.5, 0.3 + H + 4.1), METAL, seg=6)
    b.caixa((6.5, 2.2, 0.25), (0, A / 2 + 1.0, 3.5), CONCRETO_ESC)
    b.caixa((2.4, 0.1, 2.6), (0, A / 2 - 0.65, 1.6), PRETO)
    b.objeto(raiz)
    texto("TORRE BRASA", 0.5, (0, A / 2 + 2.12, 3.5), OLHA_MAIS_Y, BRANCO, raiz, "letreiro")
    l = Malha("luz_antena")
    l.esfera(0.15, (0, 0, 0), SIRENE_VERM, seg=8, aneis=6)
    l.objeto(raiz, (-4.5, 4.5, 0.3 + H + 7.7))


@asset("predios", "Casa do Suburbio (pode virar casa segura). Pintura_Casa troca a cor.")
def casa_suburbio(raiz):
    p = mat("Pintura_Casa", "#e9d6a6", 0.85)
    b = Malha("casa_suburbio")
    b.caixa((9.4, 8.4, 0.3), (0, 0, 0.15), CONCRETO)
    b.caixa((9, 8, 3.0), (0, 0, 1.8), p)
    b.casco([(-4.5, -4.0, 3.3), (-4.5, 4.0, 3.3), (-4.5, 0, 4.85),
             (4.5, -4.0, 3.3), (4.5, 4.0, 3.3), (4.5, 0, 4.85)],
            [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], p)
    for s in (-1, 1):
        y0 = s * 4.5
        baixo = [(-4.9, y0, 3.25), (4.9, y0, 3.25), (4.9, 0, 4.95), (-4.9, 0, 4.95)]
        b.prisma(baixo, [(x, y, z + 0.15) for (x, y, z) in baixo], TELHA)
    b.caixa((0.7, 0.7, 1.6), (2.6, -1.5, 5.0), TELHA)
    b.caixa((1.0, 0.1, 2.1), (-1.6, 4.03, 1.35), MADEIRA)
    b.caixa((1.6, 0.8, 0.15), (-1.6, 4.4, 0.08), CONCRETO_ESC)
    janelas = [((1.6, 4.0), "y"), ((-3.3, 4.0), "y"), ((-2, -4.0), "y"), ((2, -4.0), "y"),
               ((4.5, 1.8), "x"), ((4.5, -1.8), "x"), ((-4.5, 0), "x")]
    for (x, y), eixo in janelas:
        if eixo == "y":
            b.caixa((1.36, 0.08, 1.26), (x, y, 1.95), BRANCO)
            b.caixa((1.2, 0.1, 1.1), (x, y, 1.95), VIDRO_LOJA)
        else:
            b.caixa((0.08, 1.36, 1.26), (x, y, 1.95), BRANCO)
            b.caixa((0.1, 1.2, 1.1), (x, y, 1.95), VIDRO_LOJA)
    b.objeto(raiz)


@asset("predios", "Mercado de esquina (alvo de assalto pequeno).")
def loja(raiz):
    p = mat("Pintura_Loja", "#f3efe6", 0.85)
    verde = mat("Placa_Verde", "#1f7a4d", 0.6)
    b = Malha("loja")
    b.caixa((10.4, 8.4, 0.2), (0, 0, 0.1), CONCRETO_ESC)
    b.caixa((10, 8, 4.5), (0, 0, 2.45), p)
    b.caixa((10.2, 8.2, 0.35), (0, 0, 4.85), CONCRETO)
    b.caixa((7.2, 0.12, 2.5), (-0.9, 4.02, 1.55), METAL_ESC)
    b.caixa((7.0, 0.14, 2.3), (-0.9, 4.02, 1.55), VIDRO_LOJA)
    b.caixa((1.5, 0.14, 2.4), (3.7, 4.02, 1.4), METAL_ESC)
    b.caixa((1.3, 0.16, 2.25), (3.7, 4.02, 1.33), VIDRO)
    n = 10
    for i in range(n):
        x = -4.75 + 9.5 / n * (i + 0.5)
        b.caixa((9.5 / n, 1.6, 0.07), (x, 4.75, 3.05), VERMELHO if i % 2 == 0 else BRANCO,
                rot=(rad(-17), 0, 0))
    b.caixa((8.2, 0.22, 0.95), (0, 4.1, 3.95), verde, bisel=0.04)
    b.caixa((1.6, 1.2, 0.9), (2.5, -1.5, 5.45), METAL)
    b.objeto(raiz)
    texto("MERCADO", 0.62, (0, 4.24, 3.95), OLHA_MAIS_Y, BRANCO, raiz, "letreiro")


@asset("predios", "Galpao do Porto (esconderijo, entregas).")
def galpao_porto(raiz):
    p = mat("Pintura_Galpao", "#9aa3a8", 0.55, 0.5)
    LX, LY, H = 30.0, 20.0, 8.0
    b = Malha("galpao_porto")
    b.caixa((LX + 0.6, LY + 0.6, 0.3), (0, 0, 0.15), CONCRETO_ESC)
    b.caixa((LX, LY, H), (0, 0, 0.3 + H / 2), p)
    b.casco([(-LX / 2, -LY / 2, H + 0.3), (-LX / 2, LY / 2, H + 0.3), (-LX / 2, 0, H + 2.3),
             (LX / 2, -LY / 2, H + 0.3), (LX / 2, LY / 2, H + 0.3), (LX / 2, 0, H + 2.3)],
            [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], p)
    for s in (-1, 1):
        y0 = s * (LY / 2 + 0.4)
        baixo = [(-LX / 2 - 0.4, y0, H + 0.2), (LX / 2 + 0.4, y0, H + 0.2),
                 (LX / 2 + 0.4, 0, H + 2.35), (-LX / 2 - 0.4, 0, H + 2.35)]
        b.prisma(baixo, [(x, y, z + 0.15) for (x, y, z) in baixo], METAL_ESC)
    for i in range(int(LX)):
        x = -LX / 2 + 0.5 + i
        for s in (-1, 1):
            b.caixa((0.12, 0.06, H), (x, s * (LY / 2 + 0.03), 0.3 + H / 2), p)
    for i in range(int(LY)):
        y = -LY / 2 + 0.5 + i
        for s in (-1, 1):
            b.caixa((0.06, 0.12, H), (s * (LX / 2 + 0.03), y, 0.3 + H / 2), p)
    for x in (-7.0, 7.0):
        b.caixa((6.4, 0.2, 5.8), (x, LY / 2 + 0.1, 0.3 + 2.9), METAL_ESC)
        b.caixa((6.0, 0.24, 5.5), (x, LY / 2 + 0.1, 0.3 + 2.75), mat("Porta_Enrolar", "#c9a227", 0.5, 0.4))
    b.caixa((14, 0.3, 1.5), (0, LY / 2 + 0.15, 0.3 + H - 1.0), mat("Placa_Azul", "#1c4f8a", 0.6))
    b.objeto(raiz)
    texto("ARMAZÉM 3", 0.9, (0, LY / 2 + 0.33, 0.3 + H - 1.0), OLHA_MAIS_Y, BRANCO, raiz, "letreiro")


@asset("predios", "Oficina de pintura: entrar com o carro troca a cor e limpa a evidencia 'carro'.")
def oficina_pintura(raiz):
    p = mat("Pintura_Oficina", "#d9a441", 0.8)
    b = Malha("oficina_pintura")
    b.caixa((12.4, 10.4, 0.2), (0, 0, 0.1), CONCRETO_ESC)
    b.caixa((12, 10, 5.0), (0, 0, 2.7), p)
    b.caixa((12.2, 10.2, 0.3), (0, 0, 5.35), CONCRETO)
    b.caixa((5.6, 0.12, 3.9), (-1.5, 5.0, 2.15), METAL_ESC)
    b.caixa((5.2, 0.14, 3.7), (-1.5, 5.0, 2.05), PRETO)
    b.caixa((12.04, 10.04, 0.4), (0, 0, 0.6), mat("Faixa_Oficina", "#3a3a3d", 0.8))
    b.caixa((0.9, 0.12, 2.1), (3.8, 5.02, 1.25), MADEIRA)
    b.caixa((7.5, 0.25, 1.0), (0, 5.15, 4.55), PRETO, bisel=0.03)
    b.objeto(raiz)
    texto("PINTURA", 0.7, (0, 5.29, 4.55), OLHA_MAIS_Y, mat("Letreiro_Amarelo", "#ffd23a", 0.4,
                                                              emit="#ffcc33", forca=1.5),
          raiz, "letreiro")


# ==========================================================================
# RUAS (blocos de 12 x 12 m, rua ao longo de Y, 2 faixas de 4 m)
# ==========================================================================
def _calcadas(b, comprimento):
    for s in (-1, 1):
        b.caixa((1.85, comprimento, 0.2), (s * 5.075, 0, 0.07), CALCADA)
        b.caixa((0.15, comprimento, 0.22), (s * 4.075, 0, 0.07), MEIO_FIO)


@asset("ruas", "Bloco de rua reta 12x12 m (asfalto 8 m + calcadas). Encaixa em grade de 12 m.")
def rua_reta(raiz):
    b = Malha("rua_reta")
    b.caixa((8.0, 12.0, 0.1), (0, 0, -0.03), ASFALTO)
    _calcadas(b, 12.0)
    for y in (-4.5, -1.5, 1.5, 4.5):
        b.caixa((0.14, 1.5, 0.01), (0, y, 0.025), FAIXA_AMARELA)
    for s in (-1, 1):
        b.caixa((0.12, 12.0, 0.01), (s * 3.75, 0, 0.025), FAIXA_BRANCA)
    b.objeto(raiz)


@asset("ruas", "Cruzamento 12x12 m com faixas de pedestre.")
def rua_cruzamento(raiz):
    b = Malha("rua_cruzamento")
    b.caixa((12.0, 12.0, 0.1), (0, 0, -0.03), ASFALTO)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.caixa((2.0, 2.0, 0.2), (sx * 5.0, sy * 5.0, 0.07), CALCADA)
            b.caixa((0.15, 2.0, 0.22), (sx * 3.925, sy * 5.0, 0.07), MEIO_FIO)
            b.caixa((2.0, 0.15, 0.22), (sx * 5.0, sy * 3.925, 0.07), MEIO_FIO)
    for s in (-1, 1):
        for i in range(7):
            p = -3.0 + i * 1.0
            b.caixa((0.5, 1.6, 0.01), (p, s * 4.9, 0.025), FAIXA_BRANCA)
            b.caixa((1.6, 0.5, 0.01), (s * 4.9, p, 0.025), FAIXA_BRANCA)
    b.objeto(raiz)


# ==========================================================================
# Construcao + exportacao
# ==========================================================================
def objetos_do(coll):
    return list(coll.all_objects)


def bbox(coll):
    bpy.context.view_layer.update()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for ob in objetos_do(coll):
        if ob.type != "MESH":
            continue
        for v in ob.data.vertices:
            w = ob.matrix_world @ v.co
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def exportar(coll, caminho):
    for ob in bpy.context.view_layer.objects:
        ob.select_set(False)
    for ob in objetos_do(coll):
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=caminho, export_format="GLB", use_selection=True,
                              export_apply=True, export_extras=True,
                              export_cameras=False, export_lights=False)


print("== Construindo assets ==")
INFO = []
for categoria, nome, fn, desc in ASSETS:
    coll, raiz = novo_asset(categoria, nome, desc)
    fn(raiz)
    lo, hi = bbox(coll)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons)
               for o in objetos_do(coll) if o.type == "MESH")
    caminho = os.path.join(DIR_MODELOS, nome + ".glb")
    exportar(coll, caminho)
    # Libera os nomes (roda_*, sirene_*, ...) para o proximo asset: o glTF sai com nomes
    # limpos e no .blend as pecas ficam como "asset.peca".
    for ob in objetos_do(coll):
        if ob is not raiz:
            ob.name = f"{nome}.{ob.name}"
    INFO.append(dict(categoria=categoria, nome=nome, desc=desc, coll=coll, raiz=raiz,
                     lo=lo, hi=hi, tris=tris, kb=os.path.getsize(caminho) / 1024))
    tam = hi - lo
    print(f"  {nome:22s} {tam.x:6.2f} x {tam.y:6.2f} x {tam.z:6.2f} m  {tris:6d} tris")

# --------------------------------------------------------------------------
# Iluminacao e render
# --------------------------------------------------------------------------
mundo = bpy.data.worlds.new("Ceu")
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs[0].default_value = hexcor("#bcd3ea")
mundo.node_tree.nodes["Background"].inputs[1].default_value = 0.9


def config_render(cena, x, y, amostras):
    cena.world = mundo
    cena.render.engine = "CYCLES"
    cena.cycles.device = "CPU"
    cena.cycles.samples = amostras
    cena.cycles.use_denoising = True
    cena.render.resolution_x = x
    cena.render.resolution_y = y
    cena.render.film_transparent = False
    cena.view_settings.view_transform = "AgX"
    cena.view_settings.look = "AgX - Medium High Contrast"


def sol(cena_coll, nome="Sol"):
    s = bpy.data.lights.new(nome, "SUN")
    s.energy = 3.2
    s.angle = rad(3)
    o = bpy.data.objects.new(nome, s)
    o.rotation_euler = (rad(48), rad(8), rad(150))
    cena_coll.objects.link(o)
    return o


def mirar(cam, alvo):
    d = Vector(alvo) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


if not ARGS.sem_render:
    print("== Renderizando previews ==")
    prev = bpy.data.collections.new("_preview")
    SCENE.collection.children.link(prev)
    chao_me = bpy.data.meshes.new("chao")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=2000)
    bm.to_mesh(chao_me)
    bm.free()
    chao_me.materials.append(mat("Chao_Preview", "#d6d2c8", 0.9))
    chao = bpy.data.objects.new("chao_preview", chao_me)
    chao.location.z = -0.12
    prev.objects.link(chao)
    sol(prev)
    cam_d = bpy.data.cameras.new("cam")
    cam_d.lens = 50
    cam = bpy.data.objects.new("cam", cam_d)
    prev.objects.link(cam)
    SCENE.camera = cam
    config_render(SCENE, 480, 480, 20)
    for info in INFO:
        for i2 in INFO:
            i2["coll"].hide_render = i2 is not info
        lo, hi = info["lo"], info["hi"]
        centro = (lo + hi) / 2
        raio = max((hi - lo).length / 2, 0.3)
        dist = raio / math.tan(cam_d.angle / 2) * 1.08
        direcao = Vector((1.0, 1.25, 0.8)).normalized()
        cam.location = centro + direcao * dist
        mirar(cam, centro)
        SCENE.render.filepath = os.path.join(DIR_PREVIEWS, info["nome"] + ".png")
        bpy.ops.render.render(write_still=True)
        print("  preview", info["nome"])
    for i2 in INFO:
        i2["coll"].hide_render = False
    for ob in list(prev.objects):
        bpy.data.objects.remove(ob)
    bpy.data.collections.remove(prev)

# --------------------------------------------------------------------------
# Organiza o arquivo .blend: assets lado a lado, uma fileira por categoria
# --------------------------------------------------------------------------
y_fileira = 0.0
for categoria in CATEGORIAS:
    itens = [i for i in INFO if i["categoria"] == categoria]
    if not itens:
        continue
    x = 0.0
    prof = max(i["hi"].y - i["lo"].y for i in itens)
    for i in itens:
        larg = i["hi"].x - i["lo"].x
        x += larg / 2
        i["raiz"].location = (x - (i["lo"].x + i["hi"].x) / 2, y_fileira, 0)
        i["coll"].instance_offset = i["raiz"].location
        x += larg / 2 + 3.0
    y_fileira -= prof + 8.0

# --------------------------------------------------------------------------
# Cena de demonstracao: um cruzamento de Porto Brasa com perseguicao
# --------------------------------------------------------------------------
POR_NOME = {i["nome"]: i["coll"] for i in INFO}
demo = bpy.data.scenes.new("Cena_Demo")
config_render(demo, 1600, 900, 48)


def por(nome, loc, rz=0.0, rx=0.0, ry=0.0):
    e = bpy.data.objects.new(nome + "_inst", None)
    e.instance_type = "COLLECTION"
    e.instance_collection = POR_NOME[nome]
    e.location = loc
    e.rotation_euler = (rx, ry, rz)
    demo.collection.objects.link(e)
    return e


chao_me = bpy.data.meshes.new("chao_demo")
bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=1500)
bm.to_mesh(chao_me)
bm.free()
chao_me.materials.append(mat("Grama_Seca", "#a8a16f", 0.95))
chao = bpy.data.objects.new("chao_demo", chao_me)
chao.location.z = -0.09
demo.collection.objects.link(chao)

por("rua_cruzamento", (0, 0, 0))
for k in (1, 2, 3, 4):
    por("rua_reta", (0, 12 * k, 0))
    por("rua_reta", (0, -12 * k, 0))
    por("rua_reta", (12 * k, 0, 0), rz=pi / 2)
    por("rua_reta", (-12 * k, 0, 0), rz=pi / 2)

por("predio_centro", (-17, -17, 0))
por("loja", (14, 12.5, 0), rz=pi)
por("casa_suburbio", (16, -16, 0))
por("galpao_porto", (-27, 22, 0), rz=pi / 2)
por("oficina_pintura", (-17, 44, 0), rz=-pi / 2)
por("conteiner", (-11, 38, 0), rz=0.1)
por("camera_cctv", (9.0, 8.4, 3.2), rz=pi)

for y in (-42, -30, -18, 18, 30, 42):
    por("poste", (5.4, y, 0.17), rz=pi / 2)
    por("poste", (-5.4, y + 6, 0.17), rz=-pi / 2)
por("semaforo", (5.2, -5.2, 0.17), rz=pi)
por("semaforo", (-5.2, 5.2, 0.17))
for (x, y) in ((5.6, -26), (5.6, 34), (-5.6, -36), (26, 5.6), (38, -5.6), (-34, -5.6)):
    por("palmeira", (x, y, 0.17), rz=(x + y) * 0.3)
por("lixeira", (5.5, 8.5, 0.17))
por("hidrante", (-5.3, -9.0, 0.17))

# perseguicao: jogador no sedan, viaturas atras, helicoptero em cima
por("carro_sedan", (2.0, -12.0, 0))
por("viatura_policia", (2.3, -20.5, 0), rz=rad(-4))
por("viatura_policia", (-1.6, -28.0, 0), rz=rad(3))
por("helicoptero_policia", (7.0, -24.0, 15.0), rz=rad(8), rx=rad(-8))
por("tapete_pregos", (0, 22, 0.02))
# bloqueio na rua transversal
for x in (24.0,):
    por("barreira", (x, -2.2, 0.0), rz=pi / 2)
    por("barreira", (x, 2.2, 0.0), rz=pi / 2)
por("viatura_policia", (28.0, 0.5, 0), rz=rad(70))
for (x, y) in ((22.5, -3.8), (22.5, 0), (22.5, 3.8)):
    por("cone", (x, y, 0))
por("policial", (23.5, 4.6, 0.17), rz=pi / 2)
por("protagonista", (8.0, 6.8, 0.17), rz=rad(200))
por("carro_esportivo", (-2.0, 30.0, 0), rz=pi)

sol(demo.collection, "Sol_Demo")
cam_d = bpy.data.cameras.new("cam_demo")
cam_d.lens = 30
cam = bpy.data.objects.new("cam_demo", cam_d)
cam.location = (44, -58, 34)
demo.collection.objects.link(cam)
mirar(cam, (2, -4, 2))
demo.camera = cam

if not ARGS.sem_render:
    print("== Renderizando cena demo ==")
    demo.render.filepath = os.path.join(DIR_PREVIEWS, "_cena_demo.png")
    bpy.ops.render.render(write_still=True, scene=demo.name)

# --------------------------------------------------------------------------
# Salva .blend e catalogo
# --------------------------------------------------------------------------
bpy.context.window.scene = SCENE if bpy.context.window else None
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_BLEND, "porto_brasa_assets.blend"),
                            compress=True)

with open(os.path.join(BASE, "catalogo.csv"), "w", encoding="utf-8") as f:
    f.write("categoria,nome,largura_x_m,comprimento_y_m,altura_m,triangulos,tamanho_kb,descricao\n")
    for i in INFO:
        t = i["hi"] - i["lo"]
        f.write(f'{i["categoria"]},{i["nome"]},{t.x:.2f},{t.y:.2f},{t.z:.2f},{i["tris"]},'
                f'{i["kb"]:.0f},"{i["desc"]}"\n')
print("== Pronto ==")
