import crossvent from 'crossvent'

export default {
  drag: {
    pos: null,

    onMove (e) {
      e.preventDefault()
      const x = getCoord('clientX', e)
      const y = getCoord('clientY', e)
      this.el.style = `top:${y - this.pos.y}px;left:${x - this.pos.x}px`
      const card = getCardBehindPoint(this.el, x, y)
      if (!card || !card.classList.contains('hovered-card')) {
        document.querySelectorAll('.hovered-card').forEach(el => {
          el.classList.remove('hovered-card')
        })
        if (card) card.classList.add('hovered-card')
      }
    },

    onDown (e) {
      e.preventDefault()
      const x = getCoord('clientX', e)
      const y = getCoord('clientY', e)
      this.pos = { x, y }
      touchy(document, 'add', 'mousemove', this.onMove)
    },

    onUp (e) {
      if (!this.pos) return
      this.pos = null
      touchy(document, 'remove', 'mousemove', this.onMove)
      const x = getCoord('clientX', e)
      const y = getCoord('clientY', e)
      const card = getCardBehindPoint(this.el, x, y)
      this.el.style = `top:0px;left:0px`
      document.querySelectorAll('.hovered-card').forEach(el => {
        el.classList.remove('hovered-card')
      })
      if (card) {
        if (card.dataset.discard) this.pushEvent('discard', {})
        else this.pushEvent('drop', { i: card.dataset.i })
      }
    },

    mounted () {
      this.onMove = this.onMove.bind(this)
      this.onDown = this.onDown.bind(this)
      this.onUp = this.onUp.bind(this)
      touchy(this.el, 'add', 'mousedown', this.onDown)
      touchy(document, 'add', 'mouseup', this.onUp)
    },

    destroyed () {
      touchy(this.el, 'remove', 'mousedown', this.onDown)
      touchy(document, 'remove', 'mouseup', this.onUp)
    }
  }
}

function getCardBehindPoint (point, x, y) {
  const temp = point.className || ''
  point.className += ' hidden'
  let el = document.elementFromPoint(x, y)
  point.className = temp
  if (!el) return null
  while (!el.classList.contains('mycard')) {
    el = el.parentNode
    if (!el || el === document) return null
  }
  return el
}

function touchy (el, op, type, fn) {
  const touch = {
    mouseup: 'touchend',
    mousedown: 'touchstart',
    mousemove: 'touchmove'
  }
  const pointers = {
    mouseup: 'pointerup',
    mousedown: 'pointerdown',
    mousemove: 'pointermove'
  }
  const microsoft = {
    mouseup: 'MSPointerUp',
    mousedown: 'MSPointerDown',
    mousemove: 'MSPointerMove'
  }
  if (global.navigator.pointerEnabled) {
    crossvent[op](el, pointers[type], fn)
  } else if (global.navigator.msPointerEnabled) {
    crossvent[op](el, microsoft[type], fn)
  } else {
    crossvent[op](el, touch[type], fn)
    crossvent[op](el, type, fn)
  }
}

function getEventHost (e) {
  if (e.targetTouches && e.targetTouches.length) return e.targetTouches[0]
  if (e.changedTouches && e.changedTouches.length) return e.changedTouches[0]
  return e
}

function getCoord (coord, e) {
  const host = getEventHost(e)
  const missMap = {
    pageX: 'clientX', // IE8
    pageY: 'clientY' // IE8
  }
  if (coord in missMap && !(coord in host) && missMap[coord] in host) {
    coord = missMap[coord]
  }
  return host[coord]
}
