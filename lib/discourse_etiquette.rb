module DiscourseEtiquette
  ANALYZE_COMMENT_ENDPOINT = 'https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze'

  class AnalyzeComment
    def initialize(post)
      @post = post
    end

    def to_json
      {
        comment: {
          text: @post.raw
        },
        requestedAttributes: {
          TOXICITY: {
            scoreType: 'PROBABILITY'
          },
          SEVERE_TOXICITY: {
            scoreType: 'PROBABILITY'
          }
        },
        doNotStore: false,
        sessionId: "#{Discourse.base_url}_#{@post.user_id}"
      }.to_json
    end
  end

  def self.request_analyze_comment(post)
    analyze_comment = AnalyzeComment.new(post)

    @conn ||= Excon.new(
      "#{ANALYZE_COMMENT_ENDPOINT}?key=#{SiteSetting.etiquette_google_api_key}",
      ssl_verify_peer: true,
      retry_limit: 0
    )

    body = analyze_comment.to_json
    headers = {
      'Accept' => '*/*',
      'Content-Length' => body.bytesize,
      'Content-Type' => 'application/json',
      'User-Agent' => "Discourse/#{Discourse::VERSION::STRING}",
    }
    @conn.post(headers: headers, body: body, persistent: true)
  end

  def self.extract_value_from_analyze_comment_response(response)
    score = response['attributeScores'].map do |attribute|
      attribute.dig('summaryScore', 'value') || 0.0
    end
  end

  def self.check_post_toxicity(post)
    response = self.request_analyze_comment(post)
    scores = self.extract_value_from_analyze_comment_response(JSON.load(response.body))
    if scores['TOXICITY'] > SiteSetting.etiquette_post_min_toxicity_confidence ||
        scores['SEVERE_TOXICITY'] > SiteSetting.etiquette_post_min_severe_toxicity_confidence
      PostAction.act(
        Discourse.system_user,
        post,
        PostActionType.types[:notify_moderators],
        message: I18n.t('etiquette_flag_message')
      )
    end
  end

  def self.should_check_post?(post)
    return false if post.blank? || (!SiteSetting.etiquette_enabled?)

    # admin can choose whether to flag private messages. The message will be sent to moderators.
    return false if !SiteSetting.etiquette_check_private_message && post.topic.private_message?

    stripped = post.raw.strip

    # If the entire post is a URI we skip it. This might seem counter intuitive but
    # Discourse already has settings for max links and images for new users. If they
    # pass it means the administrator specifically allowed them.
    uri = URI(stripped) rescue nil
    return false if uri

    # Otherwise check the post!
    true
  end
end
