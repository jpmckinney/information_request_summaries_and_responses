desc 'Prints Federal Identity Program names'
task :federal_identity_program do
  output = {}

  url = 'http://www.tbs-sct.gc.ca/hgw-cgf/oversight-surveillance/communications/fip-pcim/reg-eng.asp'
  client.get(url).body.xpath('//table[1]/tbody/tr').reverse.each_with_index do |tr|
    legal_title = tr.xpath('./td[2]/text()').text.gsub(/\p{Space}+/, ' ').strip
    applied_title = tr.xpath('./td[4]/text()').text.gsub(/\p{Space}+/, ' ').strip
    unless applied_title.empty?
      output[legal_title] = applied_title
    end
  end

  puts YAML.dump(output)
end

desc 'Prints abbreviations'
task :abbreviations do
  output = {}

  urls = [
    'http://open.canada.ca/vl/dataset/ati/resource/eed0bba1-5fdf-4dfa-9aa8-bb548156b612/download/atisummaries.csv',
    'http://open.canada.ca/vl/dataset/ati/resource/91a195c7-6985-4185-a357-b067b347333c/download/atinone.csv',
  ]
  urls.each do |url|
    CSV.parse(client.get(url).body, headers: true) do |row|
      id = row.fetch('Org id')
      value = row.fetch('Org').split(/ [|-] /)[0]
      if output.key?(id)
        assert("#{output[id]} expected for #{id}, got\n#{value}"){output[id] == value}
      else
        output[id] = value
      end
    end
  end

  puts YAML.dump(Hash[*output.sort_by(&:first).flatten])
end

desc 'Prints histogram data'
task :histogram do
  counts = Hash.new(0)

  url = 'http://open.canada.ca/vl/dataset/ati/resource/eed0bba1-5fdf-4dfa-9aa8-bb548156b612/download/atisummaries.csv'
  CSV.parse(client.get(url).body, headers: true) do |row|
    if Integer(row['Number of Pages / Nombre de pages']).nonzero?
      counts[row.fetch('Org id')] += 1
    end
  end

  puts <<-END
# install.packages("ggplot2")
library(ggplot2)
dat <- data.frame(id = c(#{counts.keys.map{|k| %("#{k}")}.join(', ')}), count = c(#{counts.values.map(&:to_s).join(', ')}))
# head(dat)
ggplot(dat, aes(x=count)) + geom_histogram(binwidth=50) + scale_y_sqrt()
END

  total = counts.size.to_f
  values = counts.values
  minimum = 0
  [10, 25, 50, 100, 250, 500, 1_000, 1_000_000].each do |maximum,message|
    count = values.count{|value| value > minimum && value <= maximum}
    puts '%d (%d%%) %d-%d' % [count, (count / total * 100).round, minimum + 1, maximum]
    minimum = maximum
  end
  puts total.to_i
end
