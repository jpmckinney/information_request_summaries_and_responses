namespace :ca_on_toronto do
  def ca_on_toronto_glob(pattern)
    Dir[File.join('wip', 'ca_on_toronto', pattern)]
  end

  desc 'Download Excel files'
  task :download do
    download_multiple('ca_on_toronto', 'http://www1.toronto.ca/wps/portal/contentonly?vgnextoid=261b423c963b4310VgnVCM1000003dd60f89RCRD&vgnextchannel=1a66e03bb8d1e310VgnVCM10000071d60f89RCRD', '//div[@class="panel-body"]//@href')
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
    stack_multiple('ca_on_toronto')
  end
end
