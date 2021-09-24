import '../vendor/qrcode.min'

export default {
  qrcode: {
    mounted () {
      new QRCode(this.el, this.el.dataset.url)
    }
  }
}
