let castHandler = null
let castResponse = null
function onCastLoaded (cb) {
  if (castResponse) cb(castResponse.isAvailable)
  else castHandler = cb
}
window.__onGCastApiAvailable = function (isAvailable) {
  if (castHandler) castHandler(isAvailable)
  else castResponse = { isAvailable }
}

const CUSTOM_URN_ID = 'urn:x-cast:com.dallin.castdata'

export default {
  cast: {
    mounted () {
      const { appId, gameId } = this.el.dataset
      onCastLoaded(isAvailable => {
        if (!isAvailable) return
        const context = cast.framework.CastContext.getInstance()
        context.setOptions({
          receiverApplicationId: appId,
          autoJoinPolicy: chrome.cast.AutoJoinPolicy.ORIGIN_SCOPED
        })
        context.addEventListener(
          cast.framework.CastContextEventType.SESSION_STATE_CHANGED,
          event => {
            switch (event.sessionState) {
              case cast.framework.SessionState.SESSION_STARTED: {
                console.log('CastSession started')
                const castSession = context.getCurrentSession()
                if (castSession) {
                  castSession.sendMessage(CUSTOM_URN_ID, {
                    type: 'message',
                    text: gameId
                  })
                }
                break
              }
              case cast.framework.SessionState.SESSION_RESUMED: {
                console.log('CastSession resumed')
                break
              }
              case cast.framework.SessionState.SESSION_ENDED: {
                console.log('CastSession disconnected')
                break
              }
            }
          }
        )
      })
    }
  },
  game: {
    mounted () {
      const context = cast.framework.CastReceiverContext.getInstance()
      context.addCustomMessageListener(CUSTOM_URN_ID, customEvent => {
        if (customEvent.data.type == 'message') {
          this.pushEvent('start', { code: customEvent.data.text })
        }
      })
      const options = new cast.framework.CastReceiverOptions()
      options.disableIdleTimeout = true
      context.start(options)
    }
  }
}
