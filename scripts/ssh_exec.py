"""
Executor SSH via Tailscale — usado pelo n8n na Fase 4.
Chamada: python ssh_exec.py '{"host":"100.x.x.x","user":"guilherme","cmd":"ls /path"}'
"""
import json
import sys
import paramiko


def executar(host: str, user: str, cmd: str, key_path: str = "/home/node/.ssh/id_rsa") -> dict:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(hostname=host, username=user, key_filename=key_path, timeout=15)
        _, stdout, stderr = ssh.exec_command(cmd, timeout=120)
        saida = stdout.read().decode().strip()
        erro = stderr.read().decode().strip()
        codigo = stdout.channel.recv_exit_status()
        return {"ok": codigo == 0, "saida": saida, "erro": erro, "codigo": codigo}
    except Exception as e:
        return {"ok": False, "saida": "", "erro": str(e), "codigo": -1}
    finally:
        ssh.close()


if __name__ == "__main__":
    params = json.loads(sys.argv[1])
    resultado = executar(
        host=params["host"],
        user=params["user"],
        cmd=params["cmd"],
        key_path=params.get("key_path", "/home/node/.ssh/id_rsa"),
    )
    print(json.dumps(resultado, ensure_ascii=False))
