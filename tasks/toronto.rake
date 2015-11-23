require 'shellwords'

namespace :ca_on_toronto do
  def glob(pattern)
    Dir[File.join('summaries', 'ca_on_toronto', pattern)]
  end

  desc 'Convert Excel to CSV'
  task :excel_to_csv do
    glob('*.xls*').each do |input|
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
    inputs = glob('*.csv').reject{|path| path['output.csv']}.map{|path| Shellwords.escape(path)}.join(' ')
    `csvstack #{inputs} > #{File.join('summaries', 'ca_on_toronto', 'output.csv')}`
  end
end
