# typed: true
# frozen_string_literal: true

require "spec_helper"
require "tapioca/helpers/test/template"

module Tapioca
  class BackwardsCompatibilitySpec < SpecWithProject
    GENERIC_TYPE_RB = <<~RB
      class GenericType
        extend T::Sig
        extend T::Generic

        Elem = type_member

        sig { params(foo: Elem).void }
        def foo(foo)
        end
      end
    RB

    before do
      @project = mock_project(sorbet_dependency: false)
    end

    after do
      @project.destroy
    end

    describe "ObjectSpace WeakMap generation" do
      before do
        foo = mock_gem("foo", "0.0.1") do
          write("lib/foo.rb", <<~RB)
            Foo = ObjectSpace::WeakMap.new
          RB
        end
        @project.require_mock_gem(foo)
      end

      it "is a generic type with Sorbet < 0.5.10587" do
        @project.require_real_gem("sorbet-static", "0.5.10585")
        @project.bundle_install

        @project.tapioca("gem foo")

        assert_project_file_equal("sorbet/rbi/gems/foo@0.0.1.rbi", <<~RBI)
          # typed: true

          # DO NOT EDIT MANUALLY
          # This is an autogenerated file for types exported from the `foo` gem.
          # Please instead update this file by running `bin/tapioca gem foo`.

          Foo = T.let(T.unsafe(nil), ObjectSpace::WeakMap[T.untyped])
        RBI
      end

      it "is a non-generic type with Sorbet >= 0.5.10587" do
        @project.require_real_gem("sorbet-static", "0.5.10588")
        @project.bundle_install

        @project.tapioca("gem foo")

        assert_project_file_equal("sorbet/rbi/gems/foo@0.0.1.rbi", <<~RBI)
          # typed: true

          # DO NOT EDIT MANUALLY
          # This is an autogenerated file for types exported from the `foo` gem.
          # Please instead update this file by running `bin/tapioca gem foo`.

          Foo = T.let(T.unsafe(nil), ObjectSpace::WeakMap)
        RBI
      end
    end

    describe "serialization of T::Class and T.anything" do
      before do
        foo = mock_gem("foo", "0.0.1") do
          write("lib/foo.rb", <<~RB)
            Foo = T.type_alias { T.any(T.anything, T::Class[String]) }
          RB
        end
        @project.require_mock_gem(foo)
      end

      it "serializes both as untyped with Sorbet < 0.5.10782" do
        @project.require_real_gem("sorbet-static", "0.5.10780")
        @project.bundle_install

        @project.tapioca("gem foo")

        assert_project_file_equal("sorbet/rbi/gems/foo@0.0.1.rbi", <<~RBI)
          # typed: true

          # DO NOT EDIT MANUALLY
          # This is an autogenerated file for types exported from the `foo` gem.
          # Please instead update this file by running `bin/tapioca gem foo`.

          Foo = T.type_alias { T.untyped }
        RBI
      end

      it "serializes T::Class as untyped with Sorbet >= 0.5.10782 and < 0.5.10820" do
        @project.require_real_gem("sorbet-static", "0.5.10800")
        @project.bundle_install

        @project.tapioca("gem foo")

        assert_project_file_equal("sorbet/rbi/gems/foo@0.0.1.rbi", <<~RBI)
          # typed: true

          # DO NOT EDIT MANUALLY
          # This is an autogenerated file for types exported from the `foo` gem.
          # Please instead update this file by running `bin/tapioca gem foo`.

          Foo = T.type_alias { T.any(T.anything, T.untyped) }
        RBI
      end

      it "serializes them correctly with Sorbet >= 0.5.10820" do
        @project.require_real_gem("sorbet-static", "0.5.10860")
        @project.bundle_install

        @project.tapioca("gem foo")

        assert_project_file_equal("sorbet/rbi/gems/foo@0.0.1.rbi", <<~RBI)
          # typed: true

          # DO NOT EDIT MANUALLY
          # This is an autogenerated file for types exported from the `foo` gem.
          # Please instead update this file by running `bin/tapioca gem foo`.

          Foo = T.type_alias { T.any(T.anything, T::Class[::String]) }
        RBI
      end
    end

    describe "compilation of constants of generic types" do
      before do
        @expected_out = <<~OUT
          Compiled generic_type
                create  sorbet/rbi/gems/generic_type@0.0.1.rbi
        OUT

        @expected_rbi = <<~RBI
          # typed: true

          # DO NOT EDIT MANUALLY
          # This is an autogenerated file for types exported from the `generic_type` gem.
          # Please instead update this file by running `bin/tapioca gem generic_type`.

          class GenericType
            extend T::Generic

            Elem = type_member

            sig { params(foo: Elem).void }
            def foo(foo); end
          end
        RBI

        generic_type = mock_gem("generic_type", "0.0.1") do
          write("lib/generic_type.rb", GENERIC_TYPE_RB)
        end
        @project.require_mock_gem(generic_type)
      end

      it "must succeed on sorbet-runtime < 0.5.10554" do
        @project.require_real_gem("sorbet-static-and-runtime", "=0.5.10539")
        @project.bundle_install

        result = @project.tapioca("gem generic_type", enforce_typechecking: false)

        assert_stdout_includes(result, @expected_out)
        assert_project_file_equal("sorbet/rbi/gems/generic_type@0.0.1.rbi", @expected_rbi)
        assert_empty_stderr(result)
        assert_success_status(result)
      end

      it "must succeed on sorbet-runtime >= 0.5.10554" do
        @project.require_real_gem("sorbet-static-and-runtime", ">=0.5.10554")
        @project.bundle_install

        result = @project.tapioca("gem generic_type", enforce_typechecking: false)

        assert_stdout_includes(result, @expected_out)
        assert_project_file_equal("sorbet/rbi/gems/generic_type@0.0.1.rbi", @expected_rbi)
        assert_empty_stderr(result)
        assert_success_status(result)
      end
    end
  end
end
