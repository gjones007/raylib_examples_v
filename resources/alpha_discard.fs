#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float xoffset;

// Output fragment color
out vec4 finalColor;

void main()
{
    vec4 texelColor = texture(texture0, vec2(fragTexCoord.x + xoffset, fragTexCoord.y));
    if (texelColor.a == 0.0) discard;
    finalColor = texelColor * fragColor * colDiffuse;
}
