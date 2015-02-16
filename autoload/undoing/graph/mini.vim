function! undoing#graph#mini#render(...) "{{{
  let node = call('undoing#tree#new', a:000).root
  let current = min(map(copy(node.children), 'v:val.n')) - 1
  let lines = {
        \ 'current': current,
        \ 'content': []
        \}
  function lines.to_s(...) "{{{
    let verbose = a:0 ? a:1 : 0
    if verbose == 0
      return join(map(copy(self.content), 'v:val.to_s(0)'), "\<nl>")
    elseif verbose == 1
      return 'current: ' . self.current . "\<NL>"
            \. join(map(copy(self.content), 'v:val.to_s(1)'), "\<nl>")
    else
      return 'current: ' . self.current . "\<NL>"
            \. join(map(copy(self.content), 'v:val.to_s(2)'), "\<nl>")
    endif
  endfunction "}}}

  let line = s:line(lines)
  let item = s:item('o', node)
  let item.line = line
  call line.add_current(item)
  let lines.current += 1
  while line.active
    "echo 'render: while: '
    call insert(lines.content, line)
    "echo lines.to_s(1)
    "echo 'render: while: ' . line.to_s(2)
    let line = line.get_next_line()
  endwhile
  echo lines.to_s(0)
  return lines
endfunction "}}}

function! s:line(lines) "{{{
  let l = {}
  let l.current = 1
  let l.prev = []
  let l.lines = a:lines
  let l.n = 1
  let l.active = 0
  function l.init() "{{{
    let self.index = 0
    let self.items = []
    let self.active = 0
    let self.text = ''
    return self
  endfunction "}}}
  function l.get_next_line() "{{{
    let c = copy(self)
    let c.prev = self
    let c.n += 1
    let self.next = c
    call c.init()
    call c.populate()
    return c
  endfunction "}}}
  function l.populate() "{{{
    while self.index < len(self.prev.items)
      let item = self.prev.item(self.index)
      let [current, item] = item.spawn()
      if current
        call self.add_current(item)
        let inc_current = 1
      else
        call self.add(item)
      endif
      let self.index += 1
    endwhile
    let self.lines.current += exists('inc_current')
  endfunction "}}}
  function l.add(item) "{{{
    let a:item.line = self
    let self.active += a:item.n == -1 ? 0 : 1
    call add(self.items, a:item)
  endfunction "}}}
  function l.add_current(item) "{{{
    if a:item.children_cnt > 1
      let child = a:item.next_child()
      call self.add(a:item)
      call self.add(child)
      call self.add_padding()
    else
      call self.add(a:item)
    endif
    let self.text = printf(' [%2s]', self.lines.current)
  endfunction "}}}
  function l.item(index) "{{{
    return self.items[a:index]
  endfunction "}}}
  function l.add_padding() "{{{
    let line = self
    while !empty(line.prev)
      let line = line.prev
      if self.index + 1 == len(line.items)
        break
      endif
      let left = line.item(self.index)
      let right = line.item(self.index + 1)
      if right.type == ' ' || ( right.type ==# 'o' && empty(right.children) )
        break
      else
        let pair = left.type . right.type
        if pair =~# 'o[-+]' || pair =~# '+[-o]' || pair =~# '-[-+o]'
          let type = '-'
        else
          let type = ' '
        endif
        call insert(line.items, left.new_empty(type), self.index + 1)
      endif
    endwhile
    let self.index += 1
  endfunction "}}}
  function l.to_s(...) "{{{
    let verbose = a:0 ? a:1 : 0
    if verbose == 0
      return ' ' . join(map(copy(self.items), 'v:val.to_s(0)'), '') . self.text
    elseif verbose == 1
      return join(map(copy(self.items), 'v:val.to_s(1)'), ' ')
    else
      return printf('{n=%s, c=%s, a=%s, x: [%s]', self.n, self.lines.current, self.active, join(map(copy(self.items), 'v:val.to_s(2)'), ', '))
    endif
  endfunction "}}}
  call l.init()
  return l
endfunction "}}}

function! s:item(...) "{{{
  let i = {}
  function i.init(...) "{{{
    let self.type = a:0 ? a:1 : ' '
    let node = a:0 > 1 ? copy(a:2) : {}
    let self.n = -1
    let text = ''
    if has_key(node, 'to_s')
      " item has its own to_s()
      call remove(node, 'to_s')
    endif
    call extend(self, node)
    let self.index = a:0 > 2 ? a:3 : len(get(self, 'children', [])) - 1
    let self.children_cnt = len(get(self, 'children', []))
    return self
  endfunction "}}}
  call call(i.init, a:000, i)
  function i.new_empty(...) "{{{
    let e = copy(self)
    let type = a:0 ? a:1 : ' '
    let children = []
    return e.init(type, {}, -1)
  endfunction "}}}
  function i.is_current() "{{{
    return  self.n == self.line.lines.current
  endfunction "}}}
  function i.is_parent() "{{{
    return self.n < self.line.lines.current && self.children_cnt > 0
  endfunction "}}}
  function i.clone(...) "{{{
    let c = copy(self)
    let c.type = a:0 ? a:1 : self.type
    return c
  endfunction "}}}
  function i.next_child(...) "{{{
    let type = a:0 ? a:1 : '+'
    let i = 0
    let len = len(self.children)
    while i < len
      if self.children[i].n == self.line.lines.current
        break
      endif
      let i += 1
    endwhile
    let index = i >= len ? -1 : i
    let node = remove(self.children, index)
    let child = copy(self).init(type, node)
    if !a:0 && child.is_current()
      let child.type = 'o'
    endif
    return child
  endfunction "}}}
  function i.spawn() "{{{
    if self.n == -1
      return [0, self.new_empty()]
    elseif self.is_current()
      return [1, self.clone('o')]
    elseif self.is_parent()
      "let child = self.next_child('o')
      "if child.is_current()
      if min(map(copy(self.children), 'v:val.n')) == self.line.lines.current
        if len(self.children) == 1
          return [1, self.next_child('o')]
        else
          return [1, self.clone('+')]
        endif
      else
        return [0, self.clone('|')]
      endif
    elseif self.type == 'o' && empty(self.children)
      return [0, self.new_empty()]
    else
      return [0, self.clone('|')]
    endif
  endfunction "}}}
  function i.to_s(...) "{{{
    let verbose = a:0 ? a:1 : 0
    if verbose == 0
      return self.type
    elseif verbose == 1
      return printf('[%s %2s]', self.type, self.n)
    endif
    return '{'
          \ . 'n: ' . self.n . ', '
          \ . 't: ' . self.type . ', '
          \ . 'l: ' . self.line.n . ', '
          \ . 'i: ' . self.index . ', '
          \ . 'c: ['
          \ .   join(map(copy(self.children), 'v:val.to_s(1)'), ', ')
          \ . ']'
          \ . '}'
  endfunction "}}}
  return i
endfunction "}}}
