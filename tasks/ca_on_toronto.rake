require 'shellwords'

namespace :ca_on_toronto do
  # ca_on_toronto:excel_to_csv ca_on_toronto:stack
  def ca_on_toronto_glob(pattern)
    Dir[File.join('wip', 'ca_on_toronto', pattern)]
  end

  desc 'Download Excel files'
  task :download do
    url = 'http://www1.toronto.ca/wps/portal/contentonly?vgnextoid=261b423c963b4310VgnVCM1000003dd60f89RCRD&vgnextchannel=1a66e03bb8d1e310VgnVCM10000071d60f89RCRD'
    client.get(url).body.xpath('//div[@class="panel-body"]//@href').each do |href|
      path = href.value
      File.open(File.join(File.join('wip', 'ca_on_toronto'), File.basename(path)), 'w') do |f|
        f.write(client.get("http://www1.toronto.ca#{URI.escape(path)}").body)
      end
    end
  end

  desc 'Convert Excel to CSV'
  task :excel_to_csv do
    ca_on_toronto_glob('*.xls*').each do |input|
      unless input['_Readme.xls']
        output = input.sub(/\.xlsx?\z/, '.csv')
        # The files from 2011 contain two extra columns.
        arguments = input['2011'] ? ' -C Jacket_Number,Exemption' : ''
        `in2csv #{Shellwords.escape(input)} | csvcut -x #{arguments} > #{Shellwords.escape(output)}`
      end
    end
  end

  desc 'Stack CSV files'
  task :stack do
    inputs = ca_on_toronto_glob('*.csv').reject{|path| path['data.csv']}.map{|path| Shellwords.escape(path)}.join(' ')
    `csvstack #{inputs} > #{File.join('wip', 'ca_on_toronto', 'data.csv')}`
  end
end
