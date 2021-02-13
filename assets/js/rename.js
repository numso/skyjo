const storage = {
  get () {
    try {
      return localStorage.getItem('skyjo-name') || 'player'
    } catch (err) {
      return 'player'
    }
  },
  set (name) {
    try {
      localStorage.setItem('skyjo-name', name)
    } catch (err) {}
  }
}

export default {
  rename: {
    mounted () {
      this.pushEvent('update_name', { name: storage.get() })
      this.el.addEventListener('input', e => {
        storage.set(e.target.value)
      })
    }
  }
}
