function! s:asciiedges(seen, rev, parents)
  " Adds edge info to changelog DAG walk suitable for s:ascii()
  if index(a:seen, a:rev) == -1
    call add(a:seen, a:rev)
  endif
  let nodeidx = index(a:seen, a:rev)

  let knownparents = []
  let newparents = []
  for parent in a:parents
    if index(a:seen, parent) > -1
      call add(knownparents, parent)
    else
      call add(newparents, parent)
    endif
  endfor
  let ncols = len(a:seen)
  call remove(a:seen, nodeidx)
  call insert(a:seen, newparents, nodeidx)
  let edges = map(copy(knownparents), '[nodeidx, index(a:seen, v.val)]')
  if len(newparents) > 0
    call add(edges, [nodeidx, nodeidx])
  endif
  if len(newparents) > 1
    call add(edges, [nodeidx, nodeidx + 1])
  endif

  let nmorecols = len(a:seen) - ncols
  return [nodeidx, edges, ncols, nmorecols]
endfunction
function! s:get_nodeline_edges_tail(
      \ node_index, p_node_index, n_columns, n_columns_diff, p_diff, fix_tail
      \)
  if a:fix_tail && a:n_columns_diff == a:p_diff && a:n_columns_diff != 0
    " Still going in the same non-vertical direction.
    if a:n_columns_diff == -1
      let start = max([a:node_index + 1, a:p_node_index])
      let tail = repeat(['|', ' '], start - a:node_index - 1)
      call extend(tail, repeat(['/', ' '], a:n_columns - start))
      return tail
    else
      return repeat(['\'. ' '], a:n_columns - a:node_index - 1)
    endif
  else
    return repeat(['|', ' '], a:n_columns - a:node_index - 1)
  endif
endfunction
function! s:draw_edges(edges, nodeline, interline)
  for [start, end] in a:edges
    if start == end + 1
      let a:interline[2 * end + 1] = '/'
    elseif start == end - 1
      let a:interline[2 * start + 1] = '\'
    elseif start == end
      let a:interline[2 * start] = '|'
    else
      let a:nodeline[2 * end] = '+'
      if start > end
        let [start, end] = [end, start]
      endif
      for i in range(2 * start + 1, 2 * end)
        if a:nodeline[i] != '+'
          let a:nodeline[i] = '-'
        endif
      endfor
    endif
  endfor
endfunction
function! s:fix_long_right_edges(edges)
  let i = 0
  let len = len(a:edges)
  while i < len
    let [start, end] = a:edges[i]
    if end > start
      let a:edges[i] = [start, end + 1]
    endif
  endwhile
endfunction
function! s:ascii(buf, state, type, char, text, coldata)
  " prints an ASCII graph of the DAG

  " takes the following arguments (one call per node in the graph):

  "   - Somewhere to keep the needed state in (init to asciistate())
  "   - Column of the current node in the set of ongoing edges.
  "   - Type indicator of node data == ASCIIDATA.
  "   - Payload: (char, lines):
  "     - Character to use as node's symbol.
  "     - List of lines to display as the node's text.
  "   - Edges; a list of (col, next_col) indicating the edges between
  "     the current node and its parents.
  "   - Number of columns (ongoing edges) in the current revision.
  "   - The difference between the number of columns (ongoing edges)
  "     in the next revision and the number of columns (ongoing edges)
  "     in the current revision. That is: -1 means one column removed;
  let [idx, edges, ncols, coldiff] = a:coldata
  if coldiff < -2 || coldiff > 2
    throw 'Something something'
  endif
  if coldiff == -1
    " Transform
    "
    "     | | |        | | |
    "     o | |  into  o---+
    "     |X /         |/ /
    "     | |          | |
    call s:fix_long_right_edges(edges)
  endif

  " add_padding_line says whether to rewrite
  "
  "     | | | |        | | | |
  "     | o---+  into  | o---+
  "     |  / /         |   | |  # <--- padding line
  "     o | |          |  / /
  "                    o | |
  let add_padding_line = len(a:text) > 2 && coldiff == -1
        \ && !empty(filter(copy(edges), 'v:val[0] + 1 < v:val[1]'))

  " fix_nodeline_tail says whether to rewrite
  "
  "     | | o | |        | | o | |
  "     | | |/ /         | | |/ /
  "     | o | |    into  | o / /   # <--- fixed nodeline tail
  "     | |/ /           | |/ /
  "     o | |            o | |
  let fix_nodeline_tail = len(a:text) <= 2 && ! add_padding_line

  " nodeline is the line containing the node character (typically o)
  let nodeline = repeat(['|', ' '], idx)
  call extend(nodeline, [a:char, ' '])

  call extend(nodeline,
        \ s:get_nodeline_edges_tail(
        \   idx, a:state[1], ncols, coldiff, a:state[0], fix_nodeline_tail))

  " shift_interline is the line containing the non-vertical
  " edges between this entry and the next
  let shift_interline = repeat(['|', ' '], idx)
  if coldiff == -1
    let n_spaces = 1
    let edge_cg = '/'
  elseif coldiff == 0
    let n_spaces = 2
    let edge_ch = '|'
  else
    let n_spaces = 3
    let edge_ch = '\'
  endif
  call extend(shift_interline, repeat([' '], n_spaces))
  call extend(shift_interline, repeat([edge_ch, ' '], ncols - idx - 1))

  " draw edges from the current node to its parents.
  call s:draw_edges(edges, nodeline, shift_interline)

  " lines is the list of all graph lines to print.
  let lines = [nodeline]
  if add_padding_line
    call append(lines, s:get_padding_line(idx, ))
  endif
  call add(lines, shift_interline)

  " make sure that there are as many graph lines as there are
  " log strings
  while len(a:text) < len(lines)
    call add(a:text, '')
  endwhile
  if len(lines) < len(a:text)
    let extra_interline = repeat(['|', ' '], ncols + coldiff)
    while len(lines) < len(a:text)
      call add(lines, extra_interline)
    endwhile
  endif

  " print lines.
  let indentation_level = max([ncols, ncols + coldiff])
  for [line, logstr] in
        \ map(range(len(lines)), '[lines[v:val], a:text[v:val]]')
    let ln = printf('%-*s %s', 2 * indentation_level, join(line, ''), logstr)
    call a:buf.write(matchstr(ln, '^.*\S\ze\s*$') . "\<NL>")
  endfor

  " ... and start over.
  let a:state[0] = coldiff
  let a:state[1] = idx
endfunction
function! s:generate(dag, edgefn, current)
  let seen = []
  let state = [0,0]
  let buf = s:buffer()
  " TODO what's that list?
  for [node, parents] in a:dag
    let age_label = get(node, 'time', 'Original')
    let line = printf('[%s] %s', node.n, age_label)
    if node.n == a:current
      let char = '@'
    else
      let char = 'o'
    endif
    call s:ascii(
          \ buf, state, 'C', char, [line],
          \ call(a:edgefn, [seen, node, parents]))
  endfor
  return buf.b
endfunction
function! s:age(ts)
  let agescales = [
        \ ['year',   60 * 60 * 24 * 365],
        \ ['month',  60 * 60 * 24 * 30],
        \ ['week',   60 * 60 * 24 * 7],
        \ ['day',    60 * 60 * 24],
        \ ['hour',   60 * 60],
        \ ['minute', 60],
        \ ['second',  1]
        \ ]
  let now = localtime()
  let then = a:ts
  if then > now
    return 'in the future'
  endif
  let delta = max([1, now - then])
  if delta > agescale[0][1] * 2
    return strftime('%Y-%m-%d', a:ts)
  endif
  for [t, s] in agescale
    let n = delta / s
    if n >= 2 || s == 1
      let str = printf('%d %s', n, n == 1 ? t : t . 's')
      return printf('%s ago', str)
    endif
  endfor
endfunction
function! s:check_sanity()
  " TODO Do something useful.
  return 1
endfunction
function! s:buffer()
  let d = {}
  let d.b = ''
  function d.write(s)
    let self.b .= a:s
  endfunction
  return d
endfunction
function! s:node(n, parent, time, curhead, newhead) "{{{1
  let node = {}
  let node.n = a:n
  let node.parent = a:parent
  let node.time = a:time
  let node.curhead = a:curhead
  let node.newhead = a:newhead
  let node.children = []
  return node
endfunction
function! s:_make_nodes(alts, nodes, ...) "{{{1
  let parent = a:0 ? a:1 : {}
  for alt in a:alts
    let curhead = has_key(alt, 'curhead')
    let newhead = has_key(alt, 'newhead')
    let node = s:node(alt.seq, parent, alt.time, curhead, newhead)
    call add(a:nodes, node)
    if has_key(node, 'alt')
      call s:_make_nodes(alt.alt, nodes, parent)
    endif
    let parent = node
  endfor
endfunction
function! sacha_undo#make_nodes() "{{{1
  let undotree = undotree()
  let entries = undotree.entries
  let nodes = []
  let root = s:node(0, {}, 0, 0, 0)
  call s:_make_nodes(entries, nodes, root)
  let nmap = {}
  call add(nodes, root)
  for node in nodes
    call extend(nmap, {node.n: node})
    let node.children = filter(copy(nodes), 'v:val.parent is node')
  endfor
  return [nodes, nmap]
endfunction
function! s:changenr(nodes)
  for node in a:nodes
    if node.curhead
      return node.parent.n
    endif
  endfor
  return changenr()
endfunction
function! sacha_undo#render_graph()
  if !s:check_sanity()
    return
  endif
  let [nodes, nmap] = sacha_undo#make_nodes()
  for node in nodes
    let node.children = filter(copy(nodes), 'v:val.parent is node')
  endfor
  let dag = sort(copy(nodes), 's:compare_fn')
  let current = s:changenr(nodes)

  let string = s:generate(
        \ map(copy(dag), '[v:val, !empty(v:val.parent) ? [v:val.parent] : []]'),
        \ 's:asciiedges', current
        \ )
  let string = matchstr(string, '.*\S\ze\s*$')
  let result = split(string, "\<NL>")
  call map(result, '" " . v:val')

  return result
endfunction
function! s:compare_fn(...)
  return a:1.n == a:2.n ? 0 : a:1.n < a:2.n ? 1 : -1
endfunction
function! sacha_undo#get_state(idx) "{{{1
  let cur_idx = changenr()
  let view = winsaveview()
  exec 'undo ' . a:idx
  let lines = getline(1, '$')
  exec 'undo ' . cur_idx
  call winrestview(view)
  return lines
endfunction
function! Eval(expr) "{{{1
  return eval(a:expr)
endfunction
function! Test()
  let l1 = map(range(10), '{v:val : v:val, "parent": {}}')
  let l1[0].parent = l1[3]
  let l1[4].parent = l1[3]
  let l1[7].parent = l1[3]
  for i in l1
    echo i
    let i.children = filter(copy(l1), 'v:val.parent == i')
  endfor
  echo l1
  return l1
endfunction
"let l1 = Test()
