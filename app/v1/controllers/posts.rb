# Posts is an example controller that uses Sequel models
# directly for interacting with the database.

module V1
  module Controllers
    class Posts
      include Base
      include Praxis::Extensions::Rendering

      implements ResourceDefinitions::Posts

      BEGINCOLLECTION = '['.freeze
      ENDCOLLECTION = ']'.freeze
      SEPARATOR = ','.freeze
      def render(object, include_nil: false)
        loaded = self.media_type.load(object)
        renderer = Praxis::Renderer.new(include_nil: include_nil)
        
        o = renderer.render(loaded, self.expanded_fields)

        handlers = Praxis::Application.instance.handlers
        handler = (response.content_type && handlers[response.content_type.handler_name]) || handlers['json']


        enumerator = Enumerator.new do |yielder|
          yielder << BEGINCOLLECTION
          o.in_groups_of(25).each.with_index do |group,idx| 
            yielder << SEPARATOR unless idx == 0 
            yielder << group
          end
          yielder << ENDCOLLECTION
        end
        puts "#{enumerator.count} ELEMENTS"  
        enumerator.lazy.with_index.map do|group,idx|
#          puts ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>#{idx}"
          if group == BEGINCOLLECTION 
            '['
          elsif group == ENDCOLLECTION
            ']'
          elsif group == SEPARATOR
            ','
          else
            group.map {|elem| handler.generate(elem) }.join(',')
          end
        end
      rescue => e
        binding.pry
        puts "!!!!!#{e}"
      rescue Attributor::DumpError
        if self.media_type.domain_model == Object
          warn "Detected the rendering of an object of type #{self.media_type} without having a domain object model set.\n" +
               "Did you forget to define it?"
        end
        raise
      end

      def index(*args)
        posts = Post.all
        many = []
        5.times do
          many += posts
        end
        display(many)
      end


      def show(id:, **args)
        post = Post[id]
        if post.nil?
          return ResourceNotFound.new(id: id, type: Post)
        end

        display(post)
      end


      def create(blog_id: nil, **args)
        post_data = request.payload.part 'post'

        post = ::Post.create(
           title: post_data.body.title,
           content: post_data.body.content,
           blog_id: post_data.body.blog.id
        )

        response = Praxis::Responses::Created.new

        location = ResourceDefinitions::Posts.to_href(id: post.id)
        response.headers['Location'] = location

        response
      end

      def delete(id:)
        post = Post[id]
        if post.nil?
          return ResourceNotFound.new(id: id, type: Post)
        end

        post.delete

        Praxis::Responses::NoContent.new
      end

    end
  end
end
