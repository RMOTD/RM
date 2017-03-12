import paramiko

def sshclient_execmd(hostname, port, username, password, execmd):
    paramiko.util.log_to_file("paramiko.log")
    
    s = paramiko.SSHClient()
    s.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    s.connect(hostname=hostname, port=port, username=username, password=password)
    stdin, stdout, stderr = s.exec_command (execmd)
    stdin.write("Y")  # Generally speaking, the first connection, need a simple interaction.
    
    print stdout.read()
    
    s.close()
    
    
    
def main():
    
    hostname = '10.***.***.**'
    port = 22
    username = 'root'
    password = '******'
    execmd = "free"
    
    sshclient_execmd(hostname, port, username, password, execmd)
    
    
if __name__ == "__main__":
    main()