require "../../../spec_helper"

module Neo4j
  module PackStream
    describe Lexer do
      it "lexes nil" do
        lexer = Lexer.new("\xC0")

        lexer.next_token.type.should eq :nil
      end

      it "lexes booleans" do
        # Checking both boolean values also tests that we can lex multiple
        # values.
        lexer = Lexer.new("\xC2\xC3")

        lexer.next_token.type.should eq :false
        lexer.next_token.type.should eq :true
      end

      it "lexes strings" do
        # Byte marker and length contained within a single byte followed by
        # byte marker and length in separate bytes
        lexer = Lexer.new("\x85Jamie\xD0\x0DJamie Gaskins")

        lexer.next_token
        lexer.token.type.should eq :STRING
        lexer.token.string_value.should eq "Jamie"

        lexer.next_token
        lexer.token.type.should eq :STRING
        lexer.token.string_value.should eq "Jamie Gaskins"
      end

      it "lexes 64-bit floats from big-endian bytes" do
        lexer = Lexer.new("\xC1\x01\x23\x45\x67\x89\xAB\xCD\xEF")

        lexer.next_token
        lexer.token.type.should eq :FLOAT
        # The bytes 0123456789ABCDEF as a big-endian IEEE754 float results in a
        # very tiny positive number.
        lexer.token.float_value.should eq 3.512700564088504e-303
      end

      it "lexes integers from big-endian bytes" do
        # 0x0..0x7F = 7-bit
        # 0xC8 = 8 bit
        # 0xC9 = 16 bit
        # 0xCA = 32 bit
        # 0xCB = 64 bit
        lexer = Lexer.new("\x00\x7F\xC8\x01\xC9\x7F\x02\xCA\x00\x00\x00\x03\xCB\x10\x00\x00\x00\x00\x00\x00\x04")

        lexer.next_token.int_value.should eq 0
        lexer.next_token.int_value.should eq 0x7f
        lexer.next_token.int_value.should eq 1
        lexer.next_token.int_value.should eq 0x7f02
        lexer.next_token.int_value.should eq 3
        lexer.next_token.int_value.should eq 0x1000_0000_0000_0004
      end

      it "lexes arrays" do
        lexer = Lexer.new("\x90\x91")

        lexer.next_token
        lexer.token.type.should eq :ARRAY
        lexer.token.size.should eq 0

        lexer.next_token
        lexer.token.size.should eq 1

        lexer = Lexer.new("\xD4\x10")
        lexer.next_token
        lexer.token.type.should eq :ARRAY
        lexer.token.size.should eq 0x10
      end

      it "lexes hashes" do
        lexer = Lexer.new("\xAD").tap(&.next_token)

        lexer.token.type.should eq :HASH
        lexer.token.size.should eq 0x0D

        lexer = Lexer.new("\xD8\x80").tap(&.next_token)
        lexer.token.type.should eq :HASH
        lexer.token.size.should eq 0x80
      end

      it "lexes structures" do
        lexer = Lexer.new("\xB1").tap(&.next_token)

        lexer.token.type.should eq :STRUCTURE
        lexer.token.size.should eq 1

        lexer = Lexer.new("\xDC\x80").tap(&.next_token)
        lexer.token.type.should eq :STRUCTURE
        lexer.token.size.should eq 0x80
      end
    end
  end
end
