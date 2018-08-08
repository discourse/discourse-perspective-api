require 'rails_helper'

describe Jobs::FlagToxicPost do

  context '.execute' do
    it 'raises an error when post_id is missing' do
      expect { subject.execute({}) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'returns when it is given a non existed post' do
      expect(subject.execute(post_id: 0)).to eq nil
    end

    context 'with post' do
      let(:post) { Fabricate(:post) }

      it 'returns when the plugin it not enabled' do
        SiteSetting.etiquette_enabled = false
        SiteSetting.etiquette_flag_post_min_toxicity_enable = true
        expect(subject.execute(post_id: post.id)).to eq nil
      end

      it 'returns when the flag is not enabled' do
        SiteSetting.etiquette_enabled = true
        SiteSetting.etiquette_flag_post_min_toxicity_enable = false
        expect(subject.execute(post_id: post.id)).to eq nil
      end
    end
  end
end
