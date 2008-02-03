module Calais
  class Response
    attr_reader :rdf, :names, :relationships, :error
    
    def initialize(raw, error=nil)
      @error = error
      @names = []
      @relationships = []

      parse_rdf(raw)
      parse_names
      parse_relationships
    end
    
    def to_dot
      used = []
      id = @hpricot.at("rdf:Description//c:document//..").attributes["c:externalID"]
      
      dot = "digraph \"#{id}\"\n"
      dot += "{\n"
      dot += "\tgraph [rankdir=LR, overlap=false];\n"
      dot += "\tnode [shape = circle];"

      @relationships.each do |rel|
        dot += "\t\"#{rel.actor.name}\" -> \"#{rel.target.name}\""
        dot += " ["
        dot += "label=\""
        dot += "#{rel.metadata} " if rel.metadata
        dot += "(#{rel.type})"
        dot += "\"];\n"
        used |= [rel.actor.hash, rel.target.hash]
      end
      
      @names.each do |name|
        dot += "\t\"#{name.name}\";\n" unless used.include?(name.hash)
      end
      dot += "}\n"
      
      f = File.open("#{id}.dot", 'w')
      f.puts dot
      f.close
      
    end
    
    private
      def parse_rdf(raw)
        @rdf = CGI::unescapeHTML Hpricot.XML(raw).at("/string").inner_html
        @hpricot = Hpricot.XML(@rdf)
        @error = Hpricot.XML(response).at("/Error/Exception").inner_html rescue @error
      end
      
      def parse_names
        @names = @hpricot.root.search("rdf:Description//c:name//..").map do |ele|
          Calais::Response::Name.new(
            :name => ele.at("c:name").inner_html,
            :hash => ele.attributes["rdf:about"].split('/').last,
            :type => ele.at("rdf:type").attributes["rdf:resource"].split('/').last
          )
        end unless @error
      end
      
      def parse_relationships
        doc = Hpricot.XML(@rdf)
        doc.search("rdf:Description//c:docId//..").remove
        doc.search("rdf:Description//c:document//..").remove
        doc.search("rdf:Description//c:name//..").remove
        
        @relationships = doc.root.search("rdf:Description").map do |ele|
          relationship = ele.at("rdf:type")
          actor = relationship.next_sibling
          metadata = actor.next_sibling.attributes["rdf:resource"] ? nil : actor.next_sibling.inner_html.strip
          target = metadata ? actor.next_sibling.next_sibling : actor.next_sibling
          
          actor_name = actor ? Name.find_in_names(actor.attributes["rdf:resource"].split('/').last, @names) : nil
          target_name = target ? Name.find_in_names(target.attributes["rdf:resource"].split('/').last, @names) :  nil

          Calais::Response::Relationship.new(
            :type => relationship.attributes["rdf:resource"].split('/').last,
            :actor => actor_name,
            :target => target_name,
            :metadata => metadata
          )
        end
      end
    
    class Name
      include Comparable
      attr_accessor :name, :type, :hash
      
      def initialize(args={})
        args.each {|k,v| send("#{k}=", v)}
      end
      
      def self.find_in_names(hash, names)
        names.select {|name| name.hash == hash }.first
      end
    end
    
    class Relationship
      attr_accessor :type, :actor, :target, :metadata
      
      def initialize(args={})
        args.each {|k,v| send("#{k}=", v)}
      end
    end
  end
end