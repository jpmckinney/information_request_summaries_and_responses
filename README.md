```
curl -O http://open.canada.ca/vl/dataset/ati/resource/eed0bba1-5fdf-4dfa-9aa8-bb548156b612/download/atisummaries.csv
curl -O http://open.canada.ca/vl/dataset/ati/resource/91a195c7-6985-4185-a357-b067b347333c/download/atinone.csv
rake federal_identity_program > _data/federal_identity_program.yml
rake abbreviations > _data/abbreviations.yml
rake emails:get > _data/emails.yml
rake emails:validate
ruby scraper.rb
```
