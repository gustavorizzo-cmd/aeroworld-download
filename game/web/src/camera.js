import * as THREE from 'three';
import { angDiff, clamp, suavizar, frente, direita } from './util.js';

export class CameraJogo {
  constructor(cam, mapa) {
    this.cam = cam;
    this.mapa = mapa;
    this.yaw = 0;
    this.pitch = 0.3;
    this.distancia = 6;
    this.tArraste = -10;
    this.pos = new THREE.Vector3(0, 10, 10);
    this.alvo = new THREE.Vector3();
  }

  atualizar(dt, jogo, entrada) {
    const j = jogo.jogador;
    let a = entrada.consumirArraste();
    if (jogo.uiAberta) a = { dx: 0, dy: 0 };
    const sens = entrada.travado ? 0.6 : 1;
    if (jogo.armas.mirando) return this.mirar(dt, jogo, a, sens);
    this.miraPitch = suavizar(this.miraPitch || 0, 0, 6, dt);
    a.dx *= sens;
    a.dy *= sens;
    if (a.dx || a.dy) {
      this.yaw -= a.dx * 0.006;
      this.pitch = clamp(this.pitch + a.dy * 0.004, 0.05, 1.2);
      this.tArraste = jogo.tempo;
    }
    const livre = jogo.tempo - this.tArraste > 1.6;
    const v = j.veiculo;
    let alvoDist, alvoPitch;
    if (v) {
      this.alvo.set(v.x, v.y + 1.3, v.z);
      const vel = v.velocidade;
      if (livre && (vel > 1.5 || jogo.tempo - this.tArraste > 3)) {
        this.yaw += angDiff(this.yaw, v.h) * Math.min(1, dt * 3.2);
        alvoPitch = 0.26;
      }
      alvoDist = 8.5 + Math.min(vel, 40) * 0.09;
    } else {
      this.alvo.set(j.x, j.y + 1.55, j.z);
      if (livre && j.vel > 0.5) this.yaw += angDiff(this.yaw, j.h) * Math.min(1, dt * 1.6);
      alvoDist = 5.5;
      if (livre) alvoPitch = 0.3;
    }
    if (alvoPitch !== undefined) this.pitch = suavizar(this.pitch, alvoPitch, 2, dt);
    this.distancia = suavizar(this.distancia, alvoDist, 4, dt);

    // recua menos se houver predio entre o alvo e a camera
    let d = this.distancia;
    const atras = { x: Math.sin(this.yaw), z: Math.cos(this.yaw) };
    while (d > 2 && !this.mapa.temVisao(this.alvo.x, this.alvo.z, this.alvo.x + atras.x * d, this.alvo.z + atras.z * d)) d -= 0.5;

    const cp = Math.cos(this.pitch);
    const desejada = new THREE.Vector3(
      this.alvo.x + atras.x * cp * d,
      this.alvo.y + Math.sin(this.pitch) * d,
      this.alvo.z + atras.z * cp * d
    );
    this.pos.lerp(desejada, 1 - Math.exp(-12 * dt));
    this.cam.position.copy(this.pos);
    const f = frente(this.yaw);
    this.cam.lookAt(this.alvo.x + f.x * 2, this.alvo.y, this.alvo.z + f.z * 2);
    const fovAlvo = 62 + (v ? Math.min(v.velocidade, 40) * 0.3 : 0);
    if (Math.abs(this.cam.fov - fovAlvo) > 0.05) {
      this.cam.fov = suavizar(this.cam.fov, fovAlvo, 3, dt);
      this.cam.updateProjectionMatrix();
    }
  }

  // Camera por cima do ombro direito; o centro da tela e para onde o tiro vai.
  mirar(dt, jogo, a, sens) {
    const j = jogo.jogador;
    this.yaw -= a.dx * 0.004 * sens;
    this.miraPitch = clamp((this.miraPitch || 0) - a.dy * 0.004 * sens, -0.6, 0.7);
    this.tArraste = jogo.tempo;
    this.alvo.set(j.x, j.y + 1.55, j.z);
    const cp = Math.cos(this.miraPitch);
    const f3 = new THREE.Vector3(-Math.sin(this.yaw) * cp, Math.sin(this.miraPitch), -Math.cos(this.yaw) * cp);
    const r = direita(this.yaw);
    const desejada = this.alvo.clone().add(new THREE.Vector3(r.x * 0.75, 0.15, r.z * 0.75)).addScaledVector(f3, -2.4);
    this.pos.lerp(desejada, 1 - Math.exp(-20 * dt));
    this.cam.position.copy(this.pos);
    this.cam.lookAt(this.cam.position.clone().add(f3));
    this.cam.fov = suavizar(this.cam.fov, 50, 10, dt);
    this.cam.updateProjectionMatrix();
    this.pitch = 0.3;
  }
}
