if has('python')
  command! LeadJS python leadJs()
else
  command! LeadJS echo 'Only avaliable with +python support.'
endif

if has('python')
python << EOF

def send(program):
  import socket
  s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
  s.connect(('localhost', 8124))
  s.sendall(program)
  s.close()

def leadJs():
  import vim
  program = '\n'.join(vim.current.buffer)
  send(program)

EOF
endif

