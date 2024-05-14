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

    [SerializeField]
    public Shader dofShader;

    private Material VHS;
    private Material blur;
    private Material blur2;
    private Material dof;

    const int circleOfConfusion = 0;
    const int bokehPass = 1;
    const int postFilterPass = 2;

    [Range(0.1f, 100f)]
    public float focusDistance = 1.7f;

    [Range(0.1f, 10f)]
    public float focusRange = 4.2f;

    [Range(1f, 10f)]
	public float bokehRadius = 4f;

    private void Awake()
    {
        // Create a new material with the supplied shader.
        VHS = new Material(shader);
        blur = new Material(blurShader);
        blur2 = new Material(blurShader);
        dof = new Material(dofShader);
    }

    // OnRenderImage() is called when the camera has finished rendering.
    private void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        RenderTexture tmp = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
        //RenderTexture tmp2 = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
        RenderTexture coc = RenderTexture.GetTemporary(src.width, src.height, 0, 
        RenderTextureFormat.RHalf, RenderTextureReadWrite.Linear);

        //blur.SetInt("_KernelSize", 6);

        // render to a smaller texture
        int width = src.width / 2;
        int height = src.height / 2;
        RenderTexture dof0 = RenderTexture.GetTemporary(width, height, 0, src.format);
        RenderTexture dof1 = RenderTexture.GetTemporary(width, height, 0, src.format);

        dof.SetFloat("_FocusDistance", focusDistance);
        dof.SetFloat("_FocusRange", focusRange);
        dof.SetFloat("_BokehRadius", bokehRadius);

        Graphics.Blit(src, coc, dof, circleOfConfusion);

        // write to a smaller texture
        Graphics.Blit(src, dof0);

        // bokeh on the smaller texture
        Graphics.Blit(dof0, dof1, dof, bokehPass);
        Graphics.Blit(dof1, dof0, dof, postFilterPass);
        Graphics.Blit(dof0, dst);

        RenderTexture.ReleaseTemporary(coc);
        RenderTexture.ReleaseTemporary(dof0);
        RenderTexture.ReleaseTemporary(dof1);

        //Graphics.Blit(src, tmp, VHS);
        //Graphics.Blit(tmp, dst, blur);
        //Graphics.Blit(tmp2, dst, blur2);
        
        RenderTexture.ReleaseTemporary(tmp);
        //RenderTexture.ReleaseTemporary(tmp2);
    }
}