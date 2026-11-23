// Teclado, mouse (travado na janela quando possivel), rodinha e controles de toque.
// Botoes do mouse viram os codigos 'Mouse0' (esquerdo) e 'Mouse2' (direito);
// a rodinha vira 'WheelUp'/'WheelDown'.
export class Entrada {
  constructor(canvas) {
    this.canvas = canvas;
    this.teclas = new Set();
    this.apertadas = new Set(); // so no quadro em que a tecla desceu
    this.arraste = { dx: 0, dy: 0, ativo: false, ultimo: 0 };
    this.toque = { x: 0, y: 0, ativo: false };
    this.botoesToque = { freioMao: false, atirar: false };
    this.travado = false;
    this.aoPerderTrava = null;

    const descer = (k) => {
      if (!this.teclas.has(k)) this.apertadas.add(k);
      this.teclas.add(k);
    };
    addEventListener('keydown', (e) => {
      descer(e.code);
      if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Tab'].includes(e.code)) e.preventDefault();
    });
    addEventListener('keyup', (e) => this.teclas.delete(e.code));
    addEventListener('blur', () => this.teclas.clear());

    // mouse: botoes e rodinha
    canvas.addEventListener('mousedown', (e) => {
      if (e.button === 0 || e.button === 2) descer('Mouse' + e.button);
    });
    addEventListener('mouseup', (e) => this.teclas.delete('Mouse' + e.button));
    canvas.addEventListener('contextmenu', (e) => e.preventDefault());
    canvas.addEventListener('wheel', (e) => {
      this.apertadas.add(e.deltaY > 0 ? 'WheelDown' : 'WheelUp');
      e.preventDefault();
    }, { passive: false });

    // mouse travado: o movimento gira a camera sem precisar arrastar
    document.addEventListener('pointerlockchange', () => {
      const antes = this.travado;
      this.travado = document.pointerLockElement === canvas;
      if (antes && !this.travado && this.aoPerderTrava) this.aoPerderTrava();
    });
    addEventListener('mousemove', (e) => {
      if (!this.travado) return;
      this.arraste.dx += e.movementX;
      this.arraste.dy += e.movementY;
      this.arraste.ultimo = performance.now();
    });

    // arrastar (toque no lado direito da tela, ou mouse sem trava)
    let px = 0, py = 0, pid = null;
    canvas.addEventListener('pointerdown', (e) => {
      if (this.travado) return;
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

  travar() {
    if (matchMedia('(pointer: coarse)').matches) return;
    try {
      const r = this.canvas.requestPointerLock?.();
      if (r && r.catch) r.catch(() => {});
    } catch {
      /* sem trava: continua com arrastar */
    }
  }

  destravar() {
    if (document.pointerLockElement) document.exitPointerLock();
  }

  // Liga o joystick virtual e os botoes de toque.
  // botoes: [elemento, codigo ao tocar (ou null), nome enquanto segura (ou null)]
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
        el.setPointerCapture?.(e.pointerId);
        if (codigo) this.apertadas.add(codigo);
        if (segurar) this.botoesToque[segurar] = true;
      });
      const solta = () => segurar && (this.botoesToque[segurar] = false);
      el.addEventListener('pointerup', solta);
      el.addEventListener('pointercancel', solta);
      el.addEventListener('lostpointercapture', solta);
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

  atirando() {
    return this.tem('Mouse0') || this.botoesToque.atirar;
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

  limpar() {
    this.apertadas.clear();
    this.teclas.delete('Mouse0');
    this.teclas.delete('Mouse2');
    this.botoesToque.atirar = false;
    this.consumirArraste();
  }

  fimDoQuadro() {
    this.apertadas.clear();
  }
}
