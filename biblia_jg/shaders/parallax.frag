#version 460 core
// Efeito "3D" das ilustrações: desloca cada ponto conforme a profundidade (mapa de
// profundidade em tons de cinza: claro = perto), enquanto a câmera se move devagar.
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;   // tamanho da área na tela
uniform vec2 uImage;  // tamanho da ilustração
uniform vec2 uShift;  // posição da câmera (-1..1)
uniform float uZoom;  // 1.0 = a ilustração cobre a área
uniform float uDepth; // força do efeito (0 = desligado)
uniform float uFlip;  // 1.0 = textura de cabeça para baixo neste aparelho
uniform sampler2D tImage;
uniform sampler2D tDepth;

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy / uSize;
  float ca = uSize.x / uSize.y;
  float ia = uImage.x / uImage.y;
  vec2 scale = ca > ia ? vec2(1.0, ia / ca) : vec2(ca / ia, 1.0);
  vec2 uv = (p - 0.5) * scale / uZoom + 0.5;
  vec2 shift = uShift;
  if (uFlip > 0.5) {
    uv.y = 1.0 - uv.y;
    shift.y = -shift.y;
  }
  uv += shift * 0.008;
  vec2 off = shift * uDepth;
  float d = texture(tDepth, uv).r;
  vec2 q = uv - off * (d - 0.45);
  d = texture(tDepth, q).r;
  q = uv - off * (d - 0.45);
  fragColor = texture(tImage, clamp(q, vec2(0.002), vec2(0.998)));
}
