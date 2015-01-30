function! s:buffer()
  let d = {}
  let d.b = ''

  function d.write(s)
    let self.b .= a:s
  endfunction

  return d
endfunction

let s:agescales = [
      \ ['year',   60 * 60 * 24 * 365],
      \ ['month',  60 * 60 * 24 * 30],
      \ ['week',   60 * 60 * 24 * 7],
      \ ['day',    60 * 60 * 24],
      \ ['hour',   60 * 60],
      \ ['minute', 60],
      \ ['second',  1]
      \ ]

function! s:age(ts)
  let now = localtime()
  let then = a:ts

  if then > now
    return 'in the future'
  endif

  let delta = max([1, now - then])

  if delta > s:agescales[0][1] * 2
    return strftime('%Y-%m-%d', a:ts)
  endif

  for [t, s] in s:agescales
    let n = delta / s
    if n >= 2 || s == 1
      let str = printf('%d %s', n, n == 1 ? t : t . 's')
      return printf('%s ago', str)
    endif
  endfor
endfunction

function! undoing#graph#new(...)
  let graph = {}
  if a:0
    let graph.tree = undoing#tree#new(a:1)
  else
    let graph.tree = undoing#tree#new()
  endif

  func graph.check_sanity() dict
    " TODO Do something useful.
    return 1
  endfunc

  func graph.generate()
    let current = self.tree.changenr()
    let seen = []
    let state = [0,0]
    let buf = s:buffer()
    for [node, parents] in self.tree.dag()
      let age_label = (node.time == 0) ? 'Original' : s:age(node.time)
      let line = printf('[%s] %s', node.n, age_label)
      if node.n == current
        let char = '@'
      else
        let char = 'o'
      endif
      call undoing#graph#ascii#render(buf, state, 'C', char, [line]
            \ , [seen, node, parents])
    endfor
    return buf.b
  endfunc

  func graph.render() dict
    if ! self.check_sanity()
      return
    endif

    let string = self.generate()
    let string = matchstr(string, '.*\S\ze\s*$')
    let result = split(string, "\<NL>")
    call map(result, '" " . v:val')

    return result
  endfunc

  return graph
endfunction
