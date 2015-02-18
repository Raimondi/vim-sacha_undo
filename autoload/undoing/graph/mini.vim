function! undoing#graph#mini#render(buf, state, char, line_tail, nodes) "{{{
  if a:char == '@'
    let a:state[0] = a:nodes[1].n
  endif
  if a:nodes[1].n > a:state[1]
    let a:state[1] = a:nodes[1].n
  endif
  if a:nodes[1].n != 0
    return
  endif
  let node = a:nodes[1]
  let current = min(map(copy(node.children), 'v:val.n')) - 1
  let lines = {
        \ 'current': current,
        \ 'content': [],
        \ 'at': a:state[0]
        \}

  let line = s:line(lines)
  let item = s:item('o', node)
  let item.line = line
  call s:line_add_current(line, item)
  let lines.current += 1
  while line.active
    call insert(lines.content, line)
    let line = s:line_get_next_line(line)
  endwhile
  let tree_width = max(map(copy(lines.content), 'len(v:val.items)'))
  for line in lines.content
    call add(a:buf, s:line_to_s(line, 0, tree_width, len(a:state[1])))
  endfor
  return lines
endfunction "}}}

function! s:lines_to_s(self, ...) "{{{
  let verbose = a:0 ? a:1 : 0
  if verbose == 0
    return join(map(copy(a:self.content), 's:line_to_s(v:val, 0)'), "\<nl>")
  elseif verbose == 1
    return 'current: ' . a:self.current . "\<NL>"
          \. join(map(copy(a:self.content), 's:line_to_s(v:val, 1)'), "\<nl>")
  else
    return 'current: ' . a:self.current . "\<NL>"
          \. join(map(copy(a:self.content), 's:line_to_s(v:val, 2)'), "\<nl>")
  endif
endfunction "}}}

function! s:line(lines) "{{{
  let l = {}
  let l.current = 1
  let l.prev = []
  let l.lines = a:lines
  let l.n = 1
  let l.active = 0
  call s:line_init(l)
  return l
endfunction }}}"
function! s:line_init(self) "{{{
  let a:self.index = 0
  let a:self.items = []
  let a:self.active = 0
  let a:self.time = 0
  let a:self.text = ''
  let a:self.current = -1
  return a:self
endfunction "}}}
function! s:line_get_next_line(self) "{{{
  let c = copy(a:self)
  let c.prev = a:self
  let c.n += 1
  let a:self.next = c
  call s:line_init(c)
  call s:line_populate(c)
  return c
endfunction "}}}
function! s:line_populate(self) "{{{
  while a:self.index < len(a:self.prev.items)
    let item = s:line_item(a:self.prev, a:self.index)
    let [current, item] = s:item_spawn(item)
    if current
      call s:line_add_current(a:self, item)
      let inc_current = 1
    else
      call s:line_add(a:self, item)
    endif
    let a:self.index += 1
  endwhile
  let a:self.lines.current += exists('inc_current')
endfunction "}}}
function! s:line_add(self, item) "{{{
  let a:item.line = a:self
  let a:self.active += a:item.n == -1 ? 0 : 1
  call add(a:self.items, a:item)
endfunction "}}}
function! s:line_add_current(self, item) "{{{
  if a:item.children_cnt > 1
    let child = s:item_next_child(a:item)
    call s:line_add(a:self, a:item)
    call s:line_add(a:self, child)
    call s:line_add_padding(a:self)
  else
    call s:line_add(a:self, a:item)
  endif
  let a:self.time = a:item.time
  let a:self.current = a:item.n == 0 ? 0 : a:self.lines.current
endfunction "}}}
function! s:line_item(self, index) "{{{
  return a:self.items[a:index]
endfunction "}}}
function! s:line_add_padding(self) "{{{
  let line = a:self
  while !empty(line.prev)
    let line = line.prev
    if a:self.index + 1 == len(line.items)
      break
    endif
    let left = s:line_item(line, a:self.index)
    let right = s:line_item(line, a:self.index + 1)
    if right.type == ' ' || ( right.type ==# 'o' && empty(right.children) )
      break
    else
      let pair = left.type . right.type
      if pair =~# 'o[-+]' || pair =~# '+[-o]' || pair =~# '-[-+o]'
        let type = '-'
      else
        let type = ' '
      endif
      call insert(line.items, s:item_new_empty(left, type), a:self.index + 1)
    endif
  endwhile
  let a:self.index += 1
endfunction "}}}
function! s:line_to_s(self, ...) "{{{
  let verbose = a:0 ? a:1 : 1
  let max_len = a:0 > 1 ? a:2 : 0
  let max_num = a:0 > 2 ? a:3 : 2
  let age = a:self.current == 0 ? 'Original' : undoing#graph#age(a:self.time)
  if verbose == 0
    let items = join(map(copy(get(a:self, 'items')), 's:item_to_s(v:val, 0)'), '')
    return printf(' %-*s [%*s] %s',
          \ max_len,
          \ items,
          \ max_num,
          \ a:self.current,
          \ age
          \)
  elseif verbose == 1
    return join(map(copy(a:self.items), 's:item_to_s(v:val, 1)'), ' ')
  else
    let n = a:self.n
    let current = a:self.lines.current
    let active = a:self.active
    let items = join(map(copy(a:self.items), 's:item_to_s(v:val, 2)'), ', ')
    return printf('{n=%s, c=%s, a=%s, x: [%s]',
          \ n,
          \ current,
          \ active,
          \ items)
  endif
endfunction "}}}

function! s:item(...) "{{{
  let i = {}
  call call('s:item_init', [i] + a:000)
  return i
endfunction "}}}
function! s:item_init(self, ...) "{{{
  let a:self.type = a:0 ? a:1 : ' '
  let node = a:0 > 1 ? copy(a:2) : {}
  let a:self.n = -1
  let text = ''
  if has_key(node, 'to_s')
    " item has its own to_s()
    call remove(node, 'to_s')
  endif
  call extend(a:self, node)
  let a:self.index = a:0 > 2 ? a:3 : len(get(a:self, 'children', [])) - 1
  let a:self.children_cnt = len(get(a:self, 'children', []))
  return a:self
endfunction "}}}
function! s:item_new_empty(self, ...) "{{{
  let e = copy(a:self)
  let type = a:0 ? a:1 : ' '
  let children = []
  return s:item_init(e, type, {}, -1)
endfunction "}}}
function! s:item_is_current(self, ) "{{{
  return  a:self.n == a:self.line.lines.current
endfunction "}}}
function! s:item_is_parent(self, ) "{{{
  return a:self.n < a:self.line.lines.current && a:self.children_cnt > 0
endfunction "}}}
function! s:item_clone(self, ...) "{{{
  let c = copy(a:self)
  let c.type = a:0 ? a:1 : a:self.type
  return c
endfunction "}}}
function! s:item_next_child(self, ...) "{{{
  let type = a:0 ? a:1 : '+'
  let i = 0
  let len = len(a:self.children)
  while i < len
    if a:self.children[i].n == a:self.line.lines.current
      break
    endif
    let i += 1
  endwhile
  let index = i >= len ? -1 : i
  let node = remove(a:self.children, index)
  let child = s:item_init(copy(a:self), type, node)
  if !a:0 && s:item_is_current(child)
    let child.type = 'o'
  endif
  return child
endfunction "}}}
function! s:item_spawn(self, ) "{{{
  if a:self.n == -1
    return [0, s:item_new_empty(a:self)]
  elseif s:item_is_current(a:self)
    return [1, s:item_clone(a:self, 'o')]
  elseif s:item_is_parent(a:self)
    "let child = self.next_child('o')
    "if child.is_current()
    if min(map(copy(a:self.children), 'v:val.n')) == a:self.line.lines.current
      if len(a:self.children) == 1
        return [1, s:item_next_child(a:self, 'o')]
      else
        return [1, s:item_clone(a:self, '+')]
      endif
    else
      return [0, s:item_clone(a:self, '|')]
    endif
  elseif a:self.type == 'o' && empty(a:self.children)
    return [0, s:item_new_empty(a:self)]
  else
    return [0, s:item_clone(a:self, '|')]
  endif
endfunction "}}}
function! s:item_to_s(self, ...) "{{{
  let verbose = a:0 ? a:1 : 0
  if verbose == 0
    if a:self.type !=# 'o'
      return a:self.type
    endif
    if a:self.n == a:self.line.lines.at
      return '@'
    else
      return a:self.type
    endif
  elseif verbose == 1
    return printf('[%s %2s]', a:self.type, a:self.n)
  endif
  return '{'
        \ . 'n: ' . a:self.n . ', '
        \ . 't: ' . a:self.type . ', '
        \ . 'l: ' . a:self.line.n . ', '
        \ . 'i: ' . a:self.index . ', '
        \ . 'c: ['
        \ .   join(map(copy(a:self.children), 'v:val.to_s(1)'), ', ')
        \ . ']'
        \ . '}'
endfunction "}}}
