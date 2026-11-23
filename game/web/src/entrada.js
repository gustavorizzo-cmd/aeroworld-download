// Teclado, arrastar para girar a camera e controles de toque.
export class Entrada {
  constructor(canvas) {
    this.teclas = new Set();
    this.apertadas = new Set(); // so no quadro em que a tecla desceu
    this.arraste = { dx: 0, dy: 0, ativo: false, ultimo: 0 };
    this.toque = { x: 0, y: 0, ativo: false };
    this.botoesToque = { freioMao: false };

    addEventListener('keydown', (e) => {
      const k = e.code;
      if (!this.teclas.has(k)) this.apertadas.add(k);
      this.teclas.add(k);
      if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(k)) e.preventDefault();
    });
    addEventListener('keyup', (e) => this.teclas.delete(e.code));
    addEventListener('blur', () => this.teclas.clear());

    let px = 0, py = 0, pid = null;
    canvas.addEventListener('pointerdown', (e) => {
      if (e.pointerType === 'touch' && e.clientX < innerWidth * 0.45) return;
      pid = e.pointerId;
      px = e.clientX;
      py = e.clientY;
      this.arraste.ativo = true;
    });
    addEventListener('pointermove', (e) => {
      if (e.pointerId !== pid) return;
      this.arraste.dx += e.clientX - px;
      this.arraste.dy += e.clientY - py;
      px = e.clientX;
      py = e.clientY;
      this.arraste.ultimo = performance.now();
    });
    const soltar = (e) => {
      if (e.pointerId === pid) {
        pid = null;
        this.arraste.ativo = false;
      }
    };
    addEventListener('pointerup', soltar);
    addEventListener('pointercancel', soltar);
  }

  // Liga o joystick virtual e os botoes de toque (criados no HTML).
  ligarToque(joy, pino, botoes) {
    let id = null, cx = 0, cy = 0;
    const raio = 50;
    joy.addEventListener('pointerdown', (e) => {
      id = e.pointerId;
      const r = joy.getBoundingClientRect();
      cx = r.left + r.width / 2;
      cy = r.top + r.height / 2;
      joy.setPointerCapture(id);
      mover(e);
    });
    const mover = (e) => {
      if (e.pointerId !== id) return;
      let dx = e.clientX - cx, dy = e.clientY - cy;
      const d = Math.hypot(dx, dy);
      if (d > raio) {
        dx *= raio / d;
        dy *= raio / d;
      }
      pino.style.transform = `translate(${dx}px, ${dy}px)`;
      this.toque = { x: dx / raio, y: dy / raio, ativo: true };
    };
    joy.addEventListener('pointermove', mover);
    const fim = (e) => {
      if (e.pointerId !== id) return;
      id = null;
      pino.style.transform = '';
      this.toque = { x: 0, y: 0, ativo: false };
    };
    joy.addEventListener('pointerup', fim);
    joy.addEventListener('pointercancel', fim);

    for (const [el, codigo, segurar] of botoes) {
      el.addEventListener('pointerdown', (e) => {
        e.preventDefault();
        if (segurar) this.botoesToque[segurar] = true;
        else this.apertadas.add(codigo);
      });
      const solta = () => segurar && (this.botoesToque[segurar] = false);
      el.addEventListener('pointerup', solta);
      el.addEventListener('pointerleave', solta);
    }
  }

  tem(...cods) {
    return cods.some((c) => this.teclas.has(c));
  }

  apertou(...cods) {
    return cods.some((c) => this.apertadas.has(c));
  }

  // Eixos -1..1: x = direita, y = frente
  eixos() {
    let x = 0, y = 0;
    if (this.tem('KeyW', 'ArrowUp')) y += 1;
    if (this.tem('KeyS', 'ArrowDown')) y -= 1;
    if (this.tem('KeyD', 'ArrowRight')) x += 1;
    if (this.tem('KeyA', 'ArrowLeft')) x -= 1;
    if (this.toque.ativo) {
      x += this.toque.x;
      y -= this.toque.y;
    }
    return { x: Math.max(-1, Math.min(1, x)), y: Math.max(-1, Math.min(1, y)) };
  }

  freioMao() {
    return this.tem('Space') || this.botoesToque.freioMao;
  }

  correr() {
    return this.tem('ShiftLeft', 'ShiftRight') || (this.toque.ativo && Math.hypot(this.toque.x, this.toque.y) > 0.95);
  }

  consumirArraste() {
    const a = { dx: this.arraste.dx, dy: this.arraste.dy };
    this.arraste.dx = 0;
    this.arraste.dy = 0;
    return a;
  }

  fimDoQuadro() {
    this.apertadas.clear();
  }
}
