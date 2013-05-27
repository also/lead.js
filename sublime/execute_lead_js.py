import sublime, sublime_plugin
import socket
import json

def send(program):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect(('localhost', 8124))
    s.sendall(program)
    s.close()

class ExecuteLeadJsCommand(sublime_plugin.TextCommand):
    def run(self, edit):
        selections = self.view.sel()
        region = selections[0]
        if len(selections) == 1 and region.a == region.b:
            selections = [sublime.Region(0, self.view.size())]

        for sel in selections:
            program = self.view.substr(sel)
            send(program)
