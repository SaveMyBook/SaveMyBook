import * as THREE from 'three';

/** 尺寸以公分為單位，比例比照 6.3 吋 iPhone Pro。 */
export const PHONE = {
  W: 7.15,
  H: 14.96,
  D: 0.83,
  R: 1.12,
  SW: 6.61,
  get SH() { return this.SW * 852 / 393; },
  SR: 0.96,
};
const PT = PHONE.SW / 393;

export function roundedRect(w: number, h: number, r: number) {
  const s = new THREE.Shape();
  const x = -w / 2, y = -h / 2;
  s.moveTo(x + r, y);
  s.lineTo(x + w - r, y);
  s.absarc(x + w - r, y + r, r, -Math.PI / 2, 0, false);
  s.lineTo(x + w, y + h - r);
  s.absarc(x + w - r, y + h - r, r, 0, Math.PI / 2, false);
  s.lineTo(x + r, y + h);
  s.absarc(x + r, y + h - r, r, Math.PI / 2, Math.PI, false);
  s.lineTo(x, y + r);
  s.absarc(x + r, y + r, r, Math.PI, Math.PI * 1.5, false);
  return s;
}

function flatShape(shape: THREE.Shape, segments = 32) {
  const g = new THREE.ShapeGeometry(shape, segments);
  g.computeBoundingBox();
  const b = g.boundingBox!;
  const uv = g.attributes.uv as THREE.BufferAttribute;
  const pos = g.attributes.position as THREE.BufferAttribute;
  for (let i = 0; i < uv.count; i++) {
    uv.setXY(i, (pos.getX(i) - b.min.x) / (b.max.x - b.min.x), (pos.getY(i) - b.min.y) / (b.max.y - b.min.y));
  }
  return g;
}

const screenVert = /* glsl */`
  varying vec2 vUv;
  void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }
`;
const screenFrag = /* glsl */`
  uniform sampler2D mapA;
  uniform sampler2D mapB;
  uniform float mixT;
  uniform float hasA;
  uniform float hasB;
  uniform float glow;
  uniform vec3 blank;
  varying vec2 vUv;
  void main() {
    vec4 a = mix(vec4(blank, 1.0), texture2D(mapA, vUv), hasA);
    vec4 b = mix(vec4(blank, 1.0), texture2D(mapB, vUv), hasB);
    float t = smoothstep(0.0, 1.0, mixT);
    vec4 c = mix(a, b, t);
    c.rgb *= glow;
    gl_FragColor = c;
    #include <colorspace_fragment>
  }
`;

const popFrag = /* glsl */`
  uniform sampler2D map;
  uniform vec4 rect;
  uniform vec2 size;
  uniform float radius;
  varying vec2 vUv;
  float sdBox(vec2 p, vec2 b, float r) { vec2 q = abs(p) - b + r; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r; }
  void main() {
    vec2 p = (vUv - 0.5) * size;
    float d = sdBox(p, size * 0.5, radius);
    float a = 1.0 - smoothstep(-0.6, 0.6, d);
    vec2 uv = vec2(mix(rect.x, rect.z, vUv.x), mix(rect.y, rect.w, vUv.y));
    vec4 c = texture2D(map, uv);
    gl_FragColor = vec4(c.rgb, a);
    #include <colorspace_fragment>
  }
`;
const shadowFrag = /* glsl */`
  uniform vec2 size;
  uniform float radius;
  uniform float blur;
  uniform float strength;
  varying vec2 vUv;
  float sdBox(vec2 p, vec2 b, float r) { vec2 q = abs(p) - b + r; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r; }
  void main() {
    vec2 full = size + vec2(blur * 4.0);
    vec2 p = (vUv - 0.5) * full;
    float d = sdBox(p, size * 0.5, radius);
    float a = (1.0 - smoothstep(-blur, blur * 1.6, d)) * strength;
    gl_FragColor = vec4(0.08, 0.12, 0.15, a);
  }
`;

export interface PopRect { x: number; y: number; w: number; h: number; r?: number }

export class PopCard {
  readonly group = new THREE.Group();
  private card: THREE.Mesh<THREE.PlaneGeometry, THREE.ShaderMaterial>;
  private shadow: THREE.Mesh<THREE.PlaneGeometry, THREE.ShaderMaterial>;
  private base: THREE.Vector3;
  constructor(readonly rect: PopRect, z: number) {
    const w = rect.w * PT, h = rect.h * PT, r = rect.r ?? 16;
    this.base = new THREE.Vector3((rect.x + rect.w / 2) * PT - PHONE.SW / 2, PHONE.SH / 2 - (rect.y + rect.h / 2) * PT, z);
    this.group.position.copy(this.base);
    this.card = new THREE.Mesh(
      new THREE.PlaneGeometry(w, h),
      new THREE.ShaderMaterial({
        vertexShader: screenVert,
        fragmentShader: popFrag,
        transparent: true,
        uniforms: {
          map: { value: null },
          rect: { value: new THREE.Vector4(rect.x / 393, 1 - (rect.y + rect.h) / 852, (rect.x + rect.w) / 393, 1 - rect.y / 852) },
          size: { value: new THREE.Vector2(rect.w, rect.h) },
          radius: { value: r },
        },
      }),
    );
    const blur = 14;
    this.shadow = new THREE.Mesh(
      new THREE.PlaneGeometry(w + blur * 4 * PT, h + blur * 4 * PT),
      new THREE.ShaderMaterial({
        vertexShader: screenVert,
        fragmentShader: shadowFrag,
        transparent: true,
        depthWrite: false,
        uniforms: {
          size: { value: new THREE.Vector2(rect.w, rect.h) },
          radius: { value: r },
          blur: { value: blur },
          strength: { value: 0 },
        },
      }),
    );
    this.card.renderOrder = 3;
    this.shadow.renderOrder = 2;
    this.group.add(this.shadow, this.card);
    this.group.visible = false;
  }

  setTexture(tex: THREE.Texture | null) { this.card.material.uniforms.map.value = tex; }

  /** t：0 貼在螢幕上，1 完全浮出。 */
  set(t: number) {
    this.group.visible = t > 0.001 && this.card.material.uniforms.map.value !== null;
    const lift = t * 1.9;
    this.card.position.set(0, t * 0.15, lift);
    this.card.scale.setScalar(1 + t * 0.07);
    this.shadow.position.set(t * 0.18, -t * 0.32, 0.004);
    this.shadow.scale.setScalar(1 + t * 0.12);
    this.shadow.material.uniforms.strength.value = 0.42 * Math.min(1, t * 1.6);
  }
}

export class Phone {
  readonly group = new THREE.Group();
  readonly body = new THREE.Group();
  readonly screen: THREE.Mesh<THREE.ShapeGeometry, THREE.ShaderMaterial>;
  readonly pops = new Map<string, PopCard>();
  private screenZ: number;

  constructor() {
    const { W, H, D, R, SW, SH, SR } = PHONE;
    const bev = 0.14;
    const frameGeo = new THREE.ExtrudeGeometry(roundedRect(W - bev * 2, H - bev * 2, R - bev), {
      depth: D - bev * 2, bevelEnabled: true, bevelThickness: bev, bevelSize: bev, bevelSegments: 6, curveSegments: 28,
    });
    frameGeo.translate(0, 0, -(D - bev * 2) / 2);
    const titanium = new THREE.MeshPhysicalMaterial({ color: 0xbec8cf, metalness: 0.92, roughness: 0.3, clearcoat: 0.25, clearcoatRoughness: 0.3 });
    const frame = new THREE.Mesh(frameGeo, titanium);

    const front = new THREE.Mesh(
      flatShape(roundedRect(W - 0.1, H - 0.1, R - 0.05)),
      new THREE.MeshPhysicalMaterial({ color: 0x06090c, roughness: 0.12, metalness: 0, clearcoat: 1, clearcoatRoughness: 0.04 }),
    );
    front.position.z = D / 2 + 0.002;

    this.screenZ = D / 2 + 0.016;
    this.screen = new THREE.Mesh(
      flatShape(roundedRect(SW, SH, SR), 40),
      new THREE.ShaderMaterial({
        vertexShader: screenVert,
        fragmentShader: screenFrag,
        uniforms: {
          mapA: { value: null }, mapB: { value: null }, mixT: { value: 0 },
          hasA: { value: 0 }, hasB: { value: 0 }, glow: { value: 1 },
          blank: { value: new THREE.Color(0xf3f5f7) },
        },
      }),
    );
    this.screen.position.z = this.screenZ;

    const island = new THREE.Mesh(
      flatShape(roundedRect(125 * PT, 36.5 * PT, 18.25 * PT)),
      new THREE.MeshBasicMaterial({ color: 0x020304 }),
    );
    island.position.set(0, SH / 2 - (11 + 18.25) * PT, this.screenZ + 0.008);

    const back = new THREE.Mesh(
      flatShape(roundedRect(W - 0.1, H - 0.1, R - 0.05)),
      new THREE.MeshPhysicalMaterial({ color: 0xcfd7dc, roughness: 0.46, metalness: 0.05, clearcoat: 0.55, clearcoatRoughness: 0.42 }),
    );
    back.position.z = -D / 2 - 0.002;
    back.rotation.y = Math.PI;

    this.body.add(frame, front, this.screen, island, back, this.cameraModule(), this.buttons());
    this.group.add(this.body);
  }

  private cameraModule() {
    const { W, H, D } = PHONE;
    const g = new THREE.Group();
    const plate = new THREE.Mesh(
      new THREE.ExtrudeGeometry(roundedRect(3.05, 3.15, 0.8), { depth: 0.06, bevelEnabled: true, bevelThickness: 0.04, bevelSize: 0.04, bevelSegments: 4, curveSegments: 20 }),
      new THREE.MeshPhysicalMaterial({ color: 0xc6cfd5, roughness: 0.3, metalness: 0.1, clearcoat: 0.8, clearcoatRoughness: 0.15 }),
    );
    plate.rotation.y = Math.PI;
    g.add(plate);
    const ring = new THREE.MeshPhysicalMaterial({ color: 0xa9b3ba, metalness: 0.95, roughness: 0.22 });
    const glass = new THREE.MeshPhysicalMaterial({ color: 0x070b10, roughness: 0.05, metalness: 0.2, clearcoat: 1, clearcoatRoughness: 0.02 });
    for (const [x, y] of [[-0.72, 0.74], [-0.72, -0.74], [0.74, 0]] as const) {
      const outer = new THREE.Mesh(new THREE.CylinderGeometry(0.62, 0.64, 0.2, 40), ring);
      outer.rotation.x = Math.PI / 2;
      outer.position.set(-x, y, -0.16);
      const lens = new THREE.Mesh(new THREE.CylinderGeometry(0.47, 0.47, 0.22, 40), glass);
      lens.rotation.x = Math.PI / 2;
      lens.position.set(-x, y, -0.17);
      g.add(outer, lens);
    }
    const flash = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.15, 0.08, 24), new THREE.MeshStandardMaterial({ color: 0xf2efe6, roughness: 0.4 }));
    flash.rotation.x = Math.PI / 2;
    flash.position.set(-0.74, 0.92, -0.1);
    const lidar = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.14, 0.08, 24), glass);
    lidar.rotation.x = Math.PI / 2;
    lidar.position.set(-0.74, -0.92, -0.1);
    g.add(flash, lidar);
    g.position.set(W / 2 - 0.36 - 1.52, H / 2 - 0.36 - 1.57, -D / 2 - 0.004);
    return g;
  }

  private buttons() {
    const { W, D } = PHONE;
    const g = new THREE.Group();
    const mat = new THREE.MeshPhysicalMaterial({ color: 0xb5bfc6, metalness: 0.92, roughness: 0.3 });
    const add = (side: number, y: number, len: number) => {
      const m = new THREE.Mesh(new THREE.CapsuleGeometry(0.09, len, 6, 12), mat);
      m.position.set(side * (W / 2 + 0.03), y, 0);
      m.scale.z = D * 0.42 / 0.09;
      g.add(m);
    };
    add(-1, 4.45, 0.42);
    add(-1, 3.25, 0.95);
    add(-1, 1.95, 0.95);
    add(1, 3.4, 1.55);
    add(1, -0.9, 0.7);
    return g;
  }

  setScreens(a: THREE.Texture | null, b: THREE.Texture | null, mix: number) {
    const u = this.screen.material.uniforms;
    u.mapA.value = a;
    u.mapB.value = b;
    u.hasA.value = a ? 1 : 0;
    u.hasB.value = b ? 1 : 0;
    u.mixT.value = mix;
  }

  addPop(id: string, rect: PopRect) {
    const card = new PopCard(rect, this.screenZ + 0.02);
    this.pops.set(id, card);
    this.body.add(card.group);
    return card;
  }

  /** 螢幕上的點（App 邏輯座標，pt）→ 世界座標。 */
  screenPoint(x: number, y: number, out = new THREE.Vector3()) {
    out.set(x * PT - PHONE.SW / 2, PHONE.SH / 2 - y * PT, this.screenZ);
    return this.body.localToWorld(out);
  }
}
