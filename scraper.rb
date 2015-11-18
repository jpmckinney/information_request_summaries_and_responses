require 'csv'
require 'yaml'

require 'nokogiri'
require 'pupa'

def assert(message)
  raise message unless yield
end

def client
  @client ||= Pupa::Processor::Client.new(cache_dir: File.expand_path('_cache', Dir.pwd), expires_in: 86400)
end

if File.exist?('urls.yml')
  URLS = YAML.load(File.read('urls.yml'))
else
  URLS = {}

  data = YAML.load(DATA)
  re = "(?:#{data['dispositions'].join('|')})"

  row_number = 1
  CSV.foreach('atisummaries.csv', headers: true) do |row|
    row_number += 1

    if row['French Summary / Sommaire de la demande en français'] && row['French Summary / Sommaire de la demande en français'][/\A#{re}/i]
      row['French Summary / Sommaire de la demande en français'], row['Disposition'] = row['Disposition'], row['French Summary / Sommaire de la demande en français']
    end

    assert("#{row_number}: expected '/' in Disposition: #{row['Disposition']}"){
      row['Disposition'].nil? || row['Disposition'][/\A#{re}\z/i] || row['Disposition'][%r{ ?/ ?}]
    }
    assert("#{row_number}: expected '|' in Org: #{row['Org']}"){
      row['Org'][/ [|-] /]
    }

    organization = row.fetch('Org').split(/ [|-] /)[0]
    number = row.fetch('Request Number / Numero de la demande')
    pages = Integer(row['Number of Pages / Nombre de pages'])

    params = {
      org: organization,
      req_num: number,
      disp: row.fetch('Disposition').to_s.split(%r{ / })[0],
      year: Integer(row.fetch('Year / Année')),
      month: Date.new(2000, Integer(row.fetch('Month / Mois (1-12)')), 1).strftime('%B'),
      pages: pages,
      req_sum: row.fetch('English Summary / Sommaire de la demande en anglais'),
      req_pages: pages,
      email: data['emails'][row.fetch('Org id')],
    }

    query = params.map do |key,value|
      if [:org, :disp].include?(key)
        "#{CGI.escape(key.to_s)}=#{value.to_s}".gsub('+', '%20')
      else
        "#{CGI.escape(key.to_s)}=#{CGI.escape(value.to_s)}".gsub('+', '%20')
      end
    end * '&'

    URLS["#{organization}-#{number}"] = "/forms/contact-ati-org?#{query}"
  end

  File.open('urls.yml', 'w') do |f|
    f.write(YAML.dump(URLS))
  end
end

def parse(url)
  client.get(url).body.xpath('//div[@class="panel panel-default"]').each do |div|
    organization = div.at_xpath('./div[@class="panel-body"]//span').text
    number = div.at_xpath('./div[@class="panel-heading"]//span').text
    expected = URLS.fetch("#{organization}-#{number}")
    actual = div.at_xpath('.//@href').value
    unless actual == expected
      puts "#{expected} expected, got\n#{actual}"
    end
  end
end

parse('http://open.canada.ca/en/search/ati')

__END__
dispositions:
- "no records existaucun document n'existe"
- "abandoned"
- "all d[io]sclosed ?"
- "all disclosed f16"
- "all disclosed {4,}Divulgation en totalité"
- "all excluded"
- "all exempted ?"
- "all material exempt"
- "aucun document existant"
- "aucune communication \\(exclusion\\)"
- "communication partielle"
- "communication totale"
- "consult other institution"
- "disclosed in full"
- "disclosed in part {4,}Divulgation en partie"
- "disclosed in part\\s?"
- "does not exist ?"
- "dublicate request"
- "full disclosure"
- "fully disclosed"
- "in part"
- "in progress"
- "information entièrement divulguée"
- "nhq release refused"
- "no information ?"
- "no record exists"
- "no record located"
- "no records exist {4,}Aucun dossier"
- "no records exist"
- "not disclosed"
- "nothing disclosed \\(excluded\\)"
- "nothing disclosed \\(exempt\\)"
- "nothing disclosed \\(exemption\\)"
- "nothing disclosed"
- "nothing to disclose"
- "partial commuinication"
- "partial communication"
- "test disposition"
- "transferred \\(ati only\\)"
- "unable to process\\s?"
emails:
  aafc-aac: ATIP-AIPRP@agr.gc.ca
  aandc-aadnc: ATIP-AIPRP@aadnc-aandc.gc.ca
  acoa-apeca: ACOA.atip-aiprp.APECA@canada.ca
  aecl-eacl: jboulais@aecl.ca
  ahrc-pac: 
  apfc-fapc: atip.coordinator@asiapacific.ca
  atssc-scdata: ATIP-AIPRP@tribunal.gc.ca
  bc: 
  bdc: 
  cannor: 
  catsa-acsta: 
  cb-cda: 
  cbc-radio-canada: 
  cbsa-asfc: 
  cca-cac: 
  ccc: 
  ccperb-cceebc: 
  cdc-ccl: 
  cdev: 
  cdic-sadc: 
  ceaa-acee: 
  ced-dec: 
  cfia-acia: 
  cgc-ccg: 
  chrc-ccdp: 
  cic: 
  cirb-ccri: 
  citt-tcce: 
  clcl-sicl: 
  cmc-mcc: 
  cmhc-schl: 
  cmhr-mcdp: 
  cmip-mciq: 
  cmn-mcn: 
  cnlopb: 
  cnsc-ccsn: 
  cpc-cpp: 
  cra-arc: 
  crtc: 
  csa-asc: 
  csc-scc: 
  csec-cstc: 
  csis-scrs: 
  csps-efpc: 
  cstm-mstc: 
  cta-otc: 
  ctc-cct: 
  dcc-cdc: 
  dfatd-maecd: 
  dfo-mpo: 
  dnd-mdn: 
  ec: 
  edc: 
  elections: 
  erc-cee: 
  esdc-edsc: 
  fcac-acfc: 
  fcc-fac: 
  feddevontario: 
  fin: 
  fintrac-canafe: 
  fntc-cfpn: 
  fpcc-cpac: 
  glpa-apgl: 
  hc-sc: 
  ic: 
  idrc-crdi: 
  infc: 
  innovation: 
  irb-cisr: 
  jccbi-pjcci: 
  jus: 
  lac-bac: 
  mai: 
  mgerc-ceegm: 
  mint-monnaie: 
  mpa-apm: 
  mpcc-cppm: 
  nac-cna: 
  ncc-ccn: 
  ndcfo-odnfc: 
  neb-one: 
  nfb-onf: 
  ngc-mbac: 
  npa-apn: 
  nrc-cnrc: 
  nrcan-rncan: 
  oag-bvg: atip-aiprp@oag-bvg.gc.ca
  oci-bec: 
  ocl-cal: 
  ocol-clo: 
  oic-ci: 
  osfi-bsif: 
  papa-appa: 
  pbc-clcc: 
  pc: 
  pch: 
  pco-bcp: 
  petf-fpet: 
  phac-aspc: 
  pmprb-cepmb: 
  ppsc-sppc: 
  pptc: 
  ps-sp: 
  psc-cfp: 
  pshcp-rssfp: 
  psi: 
  psic-ispc: 
  pslrb-crtfp: 
  pspib-oirpsp: 
  ptr: 
  pwgsc-tpsgc: 
  rcmp-grc: 
  scc-ccn: 
  sdtc-tddc: 
  sirc-csars: 
  ssc-spc: 
  sshrc-crsh: ATIP-AIPRP@sshrc-crsh.gc.ca
  statcan: 
  swc-cfc: 
  tbs-sct: 
  tc: 
  tf: 
  tsb-bst: 
  vac-acc: 
  vfpa-apvf: 
  viarail: 
  vrab-tacra: 
  wd-deo: 
  yesab-oeesy: 
