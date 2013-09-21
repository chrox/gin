require 'spec/spec_helper'

describe("Router", function()

    before_each(function()
        router = require 'core/router'
        routes = require 'core/routes'
        Controller = require 'core/controller'
        ngx = {
            HTTP_NOT_FOUND = 404,
            exit = function(code) return end,
            say = function(say) return end,
            header = { content_type = '' }
        }
    end)

    after_each(function()
        package.loaded['core/router'] = nil
        package.loaded['core/routes'] = nil
        package.loaded['core/controller'] = nil
        router = nil
        routes = nil
        Controller = nil
        ngx = nil
    end)

    describe(".handler", function()
        it("raises a 404 error if no match is found", function()
            -- redefine the matching function
            router.match = function(ngx) return end
            stub(ngx, 'exit')

            router.handler(ngx)

            assert.stub(ngx.exit).was.called_with(ngx.HTTP_NOT_FOUND)

            ngx.exit:revert()
        end)

        it("calls the action of an instance of the matched controller name", function()
            -- redefine the matching function
            router.match = function(ngx) return "controller_name", "action", "params" end

            local instance = {} -- we're going to set self to instance so we can assert on it
            local TestController = {}
            function TestController:action()
                instance = self
                return
            end
            -- dinamically load package controller_name (hack to stub a 'require' statement)
            package.loaded['controller_name'] = TestController

            spy.on(TestController, 'action')

            router.handler(ngx)

            assert.spy(TestController.action).was.called()
            assert.are.same(ngx, instance.ngx)
            assert.are.same("params", instance.params)

            TestController.action:revert()
        end)
    end)

    describe(".match", function()
        before_each(function()
            -- set routes
            routes.POST("/users", { controller = "users", action = "create" })
            routes.GET("/users", { controller = "users", action = "index" })
            routes.GET("/users/:id", { controller = "users", action = "show" })
            routes.PUT("/users/:id", { controller = "users", action = "edit" })
            routes.DELETE("/users/:user_id/messages/:id", { controller = "messages", action = "destroy" })

            router.dispatchers = routes.dispatchers
        end)

        it("returns the controller, action and params for a single param", function()
            ngx = {
                var = {
                    uri = "/users/roberto",
                    request_method = "GET"
                }
            }

            controller, action, params = router.match(ngx)

            assert.are.same("users_controller", controller)
            assert.are.same("show", action)
            assert.are.same({ id = "roberto" }, params)
        end)

        it("returns the controller, action and params for a multiple params", function()
            ngx = {
                var = {
                    uri = "/users/roberto/messages/123",
                    request_method = "DELETE"
                }
            }

            controller, action, params = router.match(ngx)

            assert.are.same("messages_controller", controller)
            assert.are.same("destroy", action)
            assert.are.same({ user_id = "roberto", id = "123" }, params)
        end)
    end)
end)
