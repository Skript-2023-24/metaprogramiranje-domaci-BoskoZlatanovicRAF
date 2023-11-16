require "google_drive"


class GoogleSheetTable
    include Enumerable
  
    def initialize(sheet)
        @sheet = sheet
        @header = sheet.rows.first { |name| name.gsub(' ', '').downcase } #moraju da se izbace razmaci iz naziva kolona
    end
  
    def to_2d_array
        @sheet.rows
    end
  
    def row(n)
        @sheet.rows[n]
    end
  
    def each
        @sheet.rows.each do |row|
        next if row.all?(&:nil?) || row.all?(&:empty?)
            yield row
        end
    end
    def header
        @header
    end
    def sheet
        @sheet
    end

    def <<(row)
        @sheet.insert_rows(@sheet.num_rows + 1, [row])
        @sheet.save
      end
    def +(other)
        @header.each_with_index do |header, index|
            raise "Headers do not match at index #{index}" unless header == other.header[index]
        end
      
        new_table = GoogleSheetTable.new(@sheet.dup)
        other.each do |row|
        new_table.sheet.insert_rows(new_table.sheet.num_rows + 1, [row])
        end
        new_table.sheet.save
    
        new_table
    end
    

    def method_missing(name, *args, &block)
        column_name = name.to_s.gsub(/(.)([A-Z])/, '\1 \2').split.map(&:capitalize).join(' ') # Converts prvaKolona to Prva Kolona
        if @header.include?(column_name)
          self[column_name]
        else
          super
        end
    end
      
    def respond_to_missing?(name, include_private = false)
        column_name = name.to_s.gsub(/(.)([A-Z])/, '\1 \2').split.map(&:capitalize).join(' ')
        @header.include?(column_name) || super
    end

    def [](column_name)
        col_index = @header.index(column_name)
        raise "Column not found" unless col_index
    
        Column.new(@sheet, col_index + 1)
    end
    
    class Column
        include Enumerable

        def initialize(sheet, col_index)
            @sheet = sheet
            @col_index = col_index
        end
    
        def [](row_index)
            @sheet[row_index + 1, @col_index]
        end
    
        def []=(row_index, value)
            @sheet[row_index + 1, @col_index] = value
            @sheet.save
        end

        def each
            @sheet.num_rows.times do |row_index|
                cell = @sheet[row_index + 1, @col_index]
                next if cell.to_s.downcase.include?('total') || cell.to_s.downcase.include?('subtotal')
                yield cell
            end
        end
        def sum
            self.reduce(0) { |sum, cell| sum + cell.to_i }
        end
        
        def avg
            self.sum / (@sheet.num_rows.to_f-1) #num_rows vraća broj redova, ali i header, pa se oduzima 1
        end

        def map
            (1...@sheet.num_rows).each do |row_index|
                self[row_index] = yield(self[row_index])
            end
        end

        def select
            result = []
            self.each_with_index do |cell, index|
              result << cell if yield(cell)
            end
            result
        end


    end
    
end
session = GoogleDrive::Session.from_config("config.json")

spreadsheet = session.spreadsheet_by_title("Test za ruby")
sheet = spreadsheet.worksheets[0]
sheet2 = spreadsheet.worksheets[1]

table = GoogleSheetTable.new(sheet)
# table2 = GoogleSheetTable.new(sheet2)
#ne radi ovo sabiranje
# table3 = table + table2
# p table3.to_2d_array
# 1.Biblioteka može da vrati dvodimenzioni niz sa vrednostima tabele
puts "1. Dvodimenzioni niz"
p table.to_2d_array

# 2.Moguće je pristupati redu preko t.row(1), i pristup njegovim elementima po sintaksi niza. 
puts "2. "
p table.row(1)


# 3.Mora biti implementiran Enumerable modul(each funkcija), gde se vraćaju sve ćelije unutar tabele, sa leva na desno. 
puts "3. Sve celije:"
table.each do |red|
  p red
end

puts "4. Merge je vec resen u biblioteci"

# 5.Biblioteka vraća celu kolonu kada se napravi upit t[“Prva Kolona”]
puts "5. a)Cela 'Prva Kolona' pre menjanja"
column = table["Prva Kolona"]

column.each do |cell|
    puts cell
end

puts "5. b) Drugi element 'Prva Kolona':"
cell = table["Prva Kolona"][1]
puts cell

puts "5. c) Update 'Prva Kolona':"
table["Prva Kolona"][1] = 2556


puts "6. i. racunanje avg i sum"
puts table.drugaKolona.sum

puts "Average of 'Druga Kolona':"
p table.drugaKolona.avg

puts "6. iii. map, select i reduce "
table.trecaKolona.map { |cell| (cell.to_i + 1).to_s }
puts "Treca kolona nakon mapiranja:"
table.trecaKolona.each do |cell|
    puts cell
end

puts "Select from 'Prva Kolona':"
selected_cells = table.prvaKolona.select { |num| num.to_i.even? }
p selected_cells

puts "reduce: "
sum = table.prvaKolona.reduce(0) { |sum, cell| sum + cell.to_i }

puts "7. total i subtotal"
puts "Sum of 'Prva Kolona':"
p sum


