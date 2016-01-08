namespace :ca_on_waterloo_region do
  def ca_on_waterloo_region_glob(pattern)
    Dir[File.join('wip', 'ca_on_waterloo_region', pattern)]
  end

  desc 'Download Excel files'
  task :download do
    download_multiple('ca_on_waterloo_region', 'http://www.regionofwaterloo.ca/en/regionalGovernment/Freedom_of_Information_Requests.asp', '//table[@class="datatable"]//ul//@href')
  end

  desc 'Convert Excel to CSV'
  task :excel_to_csv do
    ca_on_waterloo_region_glob('*.xls*').each do |input|
      output = input.sub(/\.xlsx?\z/, '.csv')
      `in2csv #{Shellwords.escape(input)} | csvcut -x | grep -v ^,,,,,,,$ > #{Shellwords.escape(output)}`
    end
  end

  desc 'Stack CSV files'
  task :stack do
    stack_multiple('ca_on_waterloo_region')
  end
end
