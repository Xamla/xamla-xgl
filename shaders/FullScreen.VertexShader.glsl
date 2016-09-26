const vec2 madd = vec2(0.5, 0.5);
attribute vec2 vertexIn;
varying vec2 textureCoord;

void main() {
   textureCoord = vertexIn.xy * madd + madd;  // scale vertex attribute to [0-1] range
   gl_Position = vec4(vertexIn.xy, 1, 1);     // set Z to 1 (far clipping plane in NDC)
}
