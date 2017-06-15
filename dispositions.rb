### Reviewing the regular expressions for classifying decisions.

# @see https://github.com/mysociety/alaveteli/blob/da6222f4e3058a9bc9ef953b9ecc84931ded8ebd/app/helpers/widget_helper.rb
require 'csv'
require 'set'

def review(set, re)
  set.select{|decision| decision[re]}.sort
end

re_parenthetical_citation = /\(.\)/
re_parenthetical = /\([^)]+\)?/

re_abandoned = /\b(?:abandon|withdrawn\b)/
re_correction = /\bcorrection\b/
re_in_progress = /\bin (?:progress|treatment)\b/
re_informal = /\binformal/
re_transferred = /\btransferred\b/
# partial after correction to avoid "correction made in part".
re_partial = /\b(?:disclosed existing records except\b|part)/
# none after partial to avoid "disclosed existing records except ..." and "disclosed in part no records exist".
re_none = /\A(?:consult other institution|disregarded|dublicate request|nhq release refused|unable to process)\z|\Aex[ce]|\b(?:all? .*\b(ex[ce]|withheld\b)|aucun|available\b|den|no(?:\b|ne\b|t)|public)/
# full after transferred to avoid "transferred out in full".
# full after partial to avoid "disclosed in part communication totale".
# full after none to avoid "all excluded exemption totale".
re_full = /\Adisclosed\z|\b(?:all (?:d|information\b)|enti|full|total)/

re_invalid = /\A(?:|\d+|[a-z]{3} \d{1,2}|electronic package sent sept28 15|other|request number|test disposition)\z/
re_matched = /\b(?:abandon|withdrawn\b)|\bcorrection\b|\bin (?:progress|treatment)\b|\binformal|\btransferred\b|\b(?:disclosed existing records except\b|part)|\A(?:consult other institution|disregarded|dublicate request|nhq release refused|unable to process)\z|\Aex[ce]|\b(?:all? .*\b(ex[ce]|withheld\b)|aucun|available\b|den|no(?:\b|ne\b|t)|public)|\Adisclosed\z|\b(?:all (?:d|information\b)|enti|full|total)/

data = []
Dir[File.join('summaries', '*.csv')].each do |path|
  if File.basename(path) == 'ca_nl.csv'
    args = ' -e iso-8859-1'
  else
    args = ''
  end
  data += CSV.parse(`csvcut#{args} -c decision #{path}`, headers: true).to_a.flatten
end
data -= ['decision'];nil # header

normal = data.map{|s|
  s.downcase.
    # Remove parenthetical citations.
    gsub(re_parenthetical_citation, '').
    # Remove notes about exemptions.
    gsub(re_parenthetical, '').
    gsub(/[\p{Punct}￼]/, ' '). # special character
    gsub(/\p{Space}+/, ' ').strip
}.reject{|s|
  s[re_invalid]
};nil

set = Set.new(normal);nil

# Review parentheticals.
Set.new(data.map{|s| s.gsub(re_parenthetical_citation, '')}.select{|s| s[/\(/]}.map{|s| s[re_parenthetical].downcase}).sort

# Review invalid.
review data.uniq, re_invalid

# Review classifications.
review set, re_abandoned
review set, re_correction
review set, re_in_progress
review set, re_informal
review set, re_transferred
review set, re_partial
review set, re_none
review set, re_full

# Left to classify.
set.reject{|s| s[re_matched]}.sort

# See how well we're doing.
normal.reject{|s| s[re_matched]}.size / normal.size.to_f * 100
set.reject{|s| s[re_matched]}.size / set.size.to_f * 100

# Report most popular for standardization.
counts = Hash.new(0)
normal.each do |s|
  counts[s] += 1
end;nil
counts.sort_by{|_,v| -v}


### Exploring BC file sizes to see what PDFs to focus on.

sizes = Dir['downloads/ca_bc/**/*'].select{|path|
  File.file?(path)
}.map{|path|
  File.size(path)
};nil
commands = sizes.join(',').scan(/(.{0,4073}),/).map.with_index{|size,i| # must be less than 4096
  "values <- c(values, #{size[0]})"
};nil

puts <<-END
library(ggplot2)
values <- c()
#{commands.join("\n")}
dat <- data.frame(count = values)
ggplot(dat, aes(x=count)) + geom_histogram() + scale_y_sqrt()
END

mb = 1024 * 1024
total_files = sizes.size.to_f
total_size = sizes.reduce(:+).to_f
large = sizes.select{|size| size > 25 * mb};nil
large.reduce(:+) / total_size * 100
large.size / total_files * 100
