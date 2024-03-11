using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Liquid : MonoBehaviour
{
    public Material material;
    [SerializeField, Range(0, 2.0f)] 
    float Agitation;

    [SerializeField]
    float Recovery;

    private float _WobbleXOverTime = 0.0f;
    private float _WobbleZOverTime = 0.0f;

    private float time = 0.0f;

    [SerializeField]
    float WobbleRange;
    [SerializeField]
    float MaxWobble;

    Vector3 _LastPosition = Vector3.zero;
    Quaternion _LastRotation = Quaternion.identity;

    void Start()
    {
        material.SetFloat("_Agitation", Agitation);
    }

    void Update()
    {
        time += Time.deltaTime;

        _WobbleXOverTime = Mathf.Lerp(_WobbleXOverTime, 0, Time.deltaTime * Recovery);
        _WobbleZOverTime = Mathf.Lerp(_WobbleZOverTime, 0, Time.deltaTime * Recovery);
        
        float _WobbleX = _WobbleXOverTime;
        float _WobbleZ = _WobbleZOverTime;

        material.SetFloat("_WobbleX", _WobbleX);
        material.SetFloat("_WobbleZ", _WobbleZ);
        material.SetVector("_ObjectOrigin", transform.position);

        Vector3 velocity = (transform.position - _LastPosition) / Time.deltaTime;
        Vector3 angularVelocity = transform.rotation.eulerAngles - _LastRotation.eulerAngles;

        _WobbleXOverTime += Mathf.Clamp((velocity.x + angularVelocity.z) * WobbleRange, -WobbleRange, WobbleRange);
        _WobbleZOverTime += Mathf.Clamp((velocity.z  + angularVelocity.x) * WobbleRange, -WobbleRange, WobbleRange);

        // this clamp shouldn't impact anything to be honest
        _WobbleXOverTime = Mathf.Clamp(_WobbleXOverTime, -MaxWobble, MaxWobble);
        _WobbleZOverTime = Mathf.Clamp(_WobbleZOverTime, -MaxWobble, MaxWobble);
        
        _LastPosition = transform.position;
        _LastRotation = transform.rotation;
    }
}
