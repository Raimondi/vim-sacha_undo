function! undoing#graph#new(...)
  let graph = {}
  if a:0
    let graph.tree = undoing#tree#new(a:1)
  else
    let graph.tree = undoing#tree#new()
  endif

  func graph.generate(...) dict
    let generator = a:0 ? a:1 : 'ascii'
    let current = self.tree.changenr()
    let seen = []
    let state = [0,0]
    let buf = []

    for [node, parents] in self.tree.dag()
      let age_label = (node.time == 0) ? 'Original' : s:age(node.time)
      let line = printf('[%s] %s', node.n, age_label)
      if node.n == current
        let char = '@'
      else
        let char = 'o'
      endif
      call call('undoing#graph#' . generator . '#render'
            \ , [buf, state, 'C', char, [line], [seen, node, parents]])
    endfor

    return buf
  endfunc

  func graph.render(...) dict
    let generator = a:0 ? a:1 : 'ascii'
    return join(map(self.generate(generator), '" " . v:val'), "\n")
  endfunc

  return graph
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
