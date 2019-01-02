# Posts is an example controller that uses Sequel models
# directly for interacting with the database.

module Streamer
  def render(object, include_nil: false)
    streamit(super(object, include_nil: include_nil))
  end
end

module V1
  module Controllers
    class Posts
      include Base
      include Praxis::Extensions::Rendering

      include Streamer
      implements ResourceDefinitions::Posts

      BEGINCOLLECTION = '['.freeze
      ENDCOLLECTION = ']'.freeze
      SEPARATOR = ','.freeze

      def streamit( objects )
        handlers = Praxis::Application.instance.handlers
        handler = (response.content_type && handlers[response.content_type.handler_name]) || handlers['json']


        enumerator = Enumerator.new do |yielder|
          yielder << BEGINCOLLECTION
          objects.in_groups_of(25).each.with_index do |group,idx| 
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
      end
      
      def index(*args)
        posts = Post.all
        many = []
        100.times do
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
