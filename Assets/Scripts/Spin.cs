using UnityEngine;

public class Spin : MonoBehaviour
{
    private GameObject target;
    [SerializeField] private float turnSpeed = 1.0f;

    private void Start()
    {
        target = gameObject;
    }

    void Update()
    {
        if (target == null) return;

        target.transform.RotateAroundLocal(Vector3.up, turnSpeed * Time.deltaTime);
    }
}
