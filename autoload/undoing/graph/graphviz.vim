function! undoing#graph#graphviz#render(buf, state, type, char, text, coldata)
  if empty(a:buf)
    call add(a:buf, [[], [], []])
    call extend(a:buf[0][0], ["digraph X {\n  node [shape = square]\n"])
  endif

  let n = a:coldata[1].n
  let t = matchstr(join(a:text, ''), '\]\s\+\zs\d\+\s\+\(\w\)')
  let c = ''
  if a:char == '@'
    let c = ' ; color = "blue"'
  endif
  call extend(a:buf[0][1], ['  s' . n . ' [label = "' . n . '\n' . t . '"' . c . ']' . "\n"])

  if a:coldata[1].n != 0
    call extend(a:buf[0][2], ['  s' . n . ' -> s' . a:coldata[2][0].n])
  endif

  if a:coldata[1].n == 0
    call extend(a:buf[0][2], ["}"])
    let a:buf[0] = join([join(a:buf[0][0], "\n"), join(a:buf[0][1], ''), join(a:buf[0][2], "\n")], '')
  endif
endfunction

