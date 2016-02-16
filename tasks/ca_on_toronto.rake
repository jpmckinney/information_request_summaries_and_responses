namespace :ca_on_toronto do
  def ca_on_toronto_glob(pattern)
    Dir[File.join('wip', 'ca_on_toronto', pattern)]
  end

  desc 'Convert Excel to CSV'
  task :excel_to_csv do
    ca_on_toronto_glob('*.xls*').each do |input|
      unless input['_Readme.xls']
        output = input.sub(/\.xlsx?\z/, '.csv')
        # The files from 2011 contain two extra columns.
        arguments = input['2011'] ? ' -C Jacket_Number,Exemption' : ''
        Open3.popen3("in2csv #{Shellwords.escape(input)} | csvcut -x #{arguments} > #{Shellwords.escape(output)}") do |stdin,stdout,stderr,wait_thr|
          unless wait_thr.value.success?
            puts "#{input}: #{stderr.read}"
          end
        end
      end
    end
  end

  desc 'Stack CSV files'
  task :stack do
    stack_multiple('ca_on_toronto')
  end
end
