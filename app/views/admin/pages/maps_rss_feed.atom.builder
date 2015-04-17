xml.instruct! :xml, :version => '1.0'
xml.rss :version => "2.0" do
  xml.channel do
    xml.title @feed_title
    xml.description @feed_description
    xml.link CartoDB.url(self, 'public_maps_home')

    @feed_items.each do |feed|
      xml.item do
        xml.title feed.name
        xml.description feed.description_html_safe
        xml.pubDate Time.parse(feed.created_at.to_s).rfc822()
        xml.link CartoDB.url(self, 'public_visualizations_public_map', {id: feed.id}, feed.user)
        xml.guid feed.id
      end
    end
  end
end

