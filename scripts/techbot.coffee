crypto = require 'crypto'

module.exports = (robot) ->

  MAP_SLACK_USER = {
    # "githubのユーザーID": "SlackのユーザーID"
    "@gh-user-1": "<@slack-user-1>"
    "@gh-user-2": "<@slack-user-2>"
  }

  MAP_SLACK_CHANNEL = {
    # "Githubのリポジトリ名": "SlackのCHANNEL ID"
    # 注意：CHANNEL名ではなくCHANNEL ID
    "gh-repo-1": "SlackRoomID1"
    "gh-repo-2": "SlackRoomID2"
  }

  # お気に入りを表示するためにリストにしていますが、lgtm.inのRandomから取得してもいいと思います
  LGTM_IMGS = [
    "http://livedoor.4.blogimg.jp/himasoku123/imgs/0/5/052ef6e2.gif"
    "http://66.media.tumblr.com/de0f12c648c123445454efc9e9b61c73/tumblr_oabbmdOo0L1u1fcuyo2_500.gif"
    "http://66.media.tumblr.com/cdbf4318f0db5c96b73f5817604a98c5/tumblr_oabbmdOo0L1u1fcuyo1_500.gif"
  ]

  MAX_LINE   = 5    # ここはお好みで
  MAX_STRING = 150  # ここもお好みで

  isCorrectSignature = (signature, body) ->
    pairs = signature.split '='
    digest_method = pairs[0]
    hmac = crypto.createHmac digest_method, process.env.HUBOT_GITHUB_SECRET
    hmac.update JSON.stringify(body), 'utf-8'
    hashed_data = hmac.digest 'hex'
    generated_signature = [digest_method, hashed_data].join '='
    return signature is generated_signature

  getSlackRoomID = (repo_name) ->
    return MAP_SLACK_CHANNEL[repo_name]

  # diff_hunkそのままだと長過ぎるので最後から5行前だけに整形する
  formatDiffHunk = (diff_hunk) ->
    return '' unless diff_hunk
    diff = ""
    diff_hunks = diff_hunk.split("\n")
    for line, i in diff_hunks by -1 when MAX_LINE >= diff_hunks.length - i
      line = line[0..MAX_STRING] + "..." if line.length > MAX_STRING
      diff = line + "\n" + diff
    return "```#{diff}``` "

  _shouldAddLGTMImg = (body) ->
    return false if body.match(/http:\/\/lgtm.in\/p\/[a-zA-Z0-9_\-]+/g) isnt null
    return body.match(/\[lgtm\]/i) || body.match(/LGTM/g)

  _getLGTMImgAtRand = () ->
    return LGTM_IMGS[(parseInt((new Date()).toFormat("SS"), 10) % LGTM_IMGS.length)]

  formatCommentBody = (body) ->
    timestamp = (new Date()).toISOString().replace(/[^0-9]/g, "")
    # GithubメンションをSlackメンションに変更
    body = body.replace(/@[a-zA-Z0-9_\-]+/g, (github_user) -> MAP_SLACK_USER[github_user] ? github_user)
    # Slackの画像キャッシュ対策
    body = body.replace(/http:\/\/lgtm.in\/p\/[a-zA-Z0-9_\-]+/g, (url) -> "#{url}?#{timestamp}")
    # おせっかい機能:LGTM画像が必要そうなら付ける
    body += "\n\n #{_getLGTMImgAtRand}?#{timestamp}" if _shouldAddLGTMImg body
    return body

  robot.router.post "/github/notice_comment", (req, res) ->
    signature = req.get 'X-Hub-Signature'
    data      = req.body
    comment   = data.comment

    unless isCorrectSignature signature, data
      return res.status(401).send 'Unauthorized'
    unless comment
      return res.status(401).send 'Not found comment'
    if data.action isnt 'created'
      return res.status(200).send ''

    room_id   = getSlackRoomID data.repository.name
    diff_hunk = formatDiffHunk comment.diff_hunk
    body      = formatCommentBody comment.body
    robot.send {room: room_id}, "From: #{comment.user.login} \nURL: #{comment.html_url} \n\n #{diff_hunk}#{body}"
    res.status(200).send 'success'