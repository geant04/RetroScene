using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RunShader : MonoBehaviour
{
    // Start is called before the first frame update
    [SerializeField]
    private Shader shader;

    [SerializeField]
    private Shader blurShader;

    private Material VHS;
    private Material blur;
    private Material blur2;

    private void Awake()
    {
        // Create a new material with the supplied shader.
        VHS = new Material(shader);
        blur = new Material(blurShader);
        blur2 = new Material(blurShader);
    }

    // OnRenderImage() is called when the camera has finished rendering.
    private void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        RenderTexture tmp = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
        //RenderTexture tmp2 = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);

        blur.SetInt("_KernelSize", 6);

        Graphics.Blit(src, tmp, VHS);
        Graphics.Blit(tmp, dst, blur);
        //Graphics.Blit(tmp2, dst, blur2);
        
        RenderTexture.ReleaseTemporary(tmp);
        //RenderTexture.ReleaseTemporary(tmp2);
    }
}