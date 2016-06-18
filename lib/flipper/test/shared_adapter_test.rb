module SharedAdapterTests
  def setup
    super
    @flipper = Flipper.new(@adapter)
    @actor_class = Struct.new(:flipper_id)
    @feature = @flipper[:stats]
    @boolean_gate = @feature.gate(:boolean)
    @group_gate = @feature.gate(:group)
    @actor_gate = @feature.gate(:actor)
    @actors_gate =  @feature.gate(:percentage_of_actors)
    @time_gate =  @feature.gate(:percentage_of_time)

    Flipper.register(:admins) do |actor|
      actor.respond_to?(:admin?) && actor.admin?
    end

    Flipper.register(:early_access) { |actor|
      actor.respond_to?(:early_access?) && actor.early_access?
    }
  end

  def teardown
    super
    Flipper.unregister_groups
  end

  def test_has_name_that_is_a_symbol
    refute_empty  @adapter.name
    assert_kind_of Symbol, @adapter.name
  end

  def test_has_included_the_flipper_adapter_module
    assert_includes  @adapter.class.ancestors, Flipper::Adapter
  end

  def test_knows_version
    assert_equal Flipper::Adapter::V1, @adapter.version
  end

  def test_returns_correct_default_values_for_gates_if_none_are_enabled
    expected = {
      :boolean => nil,
      :groups => Set.new,
      :actors => Set.new,
      :percentage_of_actors => nil,
      :percentage_of_time => nil,
    }
    assert_equal expected, @adapter.get(@feature)
  end

  def test_can_enable_disable_and_get_value_for_boolean_gate
    assert_equal true, @adapter.enable(@feature, @boolean_gate, @flipper.boolean)
    assert_equal 'true', @adapter.get(@feature)[:boolean]
    assert_equal true, @adapter.disable(@feature, @boolean_gate, @flipper.boolean(false))
    assert_equal nil, @adapter.get(@feature)[:boolean]
  end

  def test_fully_disables_all_enabled_things_when_boolean_gate_disabled
    actor_22 = @actor_class.new('22')
    assert_equal true, @adapter.enable(@feature, @boolean_gate, @flipper.boolean)
    assert_equal true, @adapter.enable(@feature, @group_gate, @flipper.group(:admins))
    assert_equal true, @adapter.enable(@feature, @actor_gate, @flipper.actor(actor_22))
    assert_equal true, @adapter.enable(@feature, @actors_gate, @flipper.actors(25))
    assert_equal true, @adapter.enable(@feature, @time_gate, @flipper.time(45))
    assert_equal true, @adapter.disable(@feature, @boolean_gate, @flipper.boolean(false))
    expected = {
      :boolean => nil,
      :groups => Set.new,
      :actors => Set.new,
      :percentage_of_actors => nil,
      :percentage_of_time => nil,
    }
    assert_equal expected, @adapter.get(@feature)
  end

  def test_can_enable_disable_get_value_for_group_gate
    assert_equal true, @adapter.enable(@feature, @group_gate, @flipper.group(:admins))
    assert_equal true, @adapter.enable(@feature, @group_gate, @flipper.group(:early_access))

    result = @adapter.get(@feature)
    assert_equal Set['admins', 'early_access'], result[:groups]

    assert_equal true, @adapter.disable(@feature, @group_gate, @flipper.group(:early_access))
    result = @adapter.get(@feature)
    assert_equal Set['admins'], result[:groups]

    assert_equal true, @adapter.disable(@feature, @group_gate, @flipper.group(:admins))
    result = @adapter.get(@feature)
    assert_equal Set.new, result[:groups]
  end

  def test_can_enable_disable_and_get_value_for_an_actor_gate
    actor_22 = @actor_class.new('22')
    actor_asdf = @actor_class.new('asdf')

    assert_equal true, @adapter.enable(@feature, @actor_gate, @flipper.actor(actor_22))
    assert_equal true, @adapter.enable(@feature, @actor_gate, @flipper.actor(actor_asdf))

    result = @adapter.get(@feature)
    assert_equal Set['22', 'asdf'], result[:actors]

    assert true, @adapter.disable(@feature, @actor_gate, @flipper.actor(actor_22))
    result = @adapter.get(@feature)
    assert_equal Set['asdf'], result[:actors]

    assert_equal true, @adapter.disable(@feature, @actor_gate, @flipper.actor(actor_asdf))
    result = @adapter.get(@feature)
    assert_equal Set.new, result[:actors]
  end

  def test_can_enable_disable_get_value_for_percentage_of_actors_gate
    assert_equal true, @adapter.enable(@feature, @actors_gate, @flipper.actors(15))
    result = @adapter.get(@feature)
    assert_equal '15', result[:percentage_of_actors]

    assert_equal true, @adapter.disable(@feature, @actors_gate, @flipper.actors(0))
    result = @adapter.get(@feature)
    assert_equal '0', result[:percentage_of_actors]
  end

  def test_can_enable_percentage_of_actors_gate_many_times_and_consistently_return_values
    (1..100).each do |percentage|
      assert_equal true, @adapter.enable(@feature, @actors_gate, @flipper.actors(percentage))
      result = @adapter.get(@feature)
      assert_equal percentage.to_s, result[:percentage_of_actors]
    end
  end

  def test_can_disable_percentage_of_actors_gate_many_times_and_consistently_return_values
    (1..100).each do |percentage|
      assert_equal true, @adapter.disable(@feature, @actors_gate, @flipper.actors(percentage))
      result = @adapter.get(@feature)
      assert_equal percentage.to_s, result[:percentage_of_actors]
    end
  end

  def test_can_enable_disable_and_get_value_for_percentage_of_time_gate
    assert_equal true, @adapter.enable(@feature, @time_gate, @flipper.time(10))
    result = @adapter.get(@feature)
    assert_equal '10', result[:percentage_of_time]

    assert_equal true, @adapter.disable(@feature, @time_gate, @flipper.time(0))
    result = @adapter.get(@feature)
    assert_equal '0', result[:percentage_of_time]
  end

  def test_can_enable_percentage_of_time_gate_many_times_and_consistently_return_values
    (1..100).each do |percentage|
      assert_equal true, @adapter.enable(@feature, @time_gate, @flipper.time(percentage))
      result = @adapter.get(@feature)
      assert_equal percentage.to_s, result[:percentage_of_time]
    end
  end

  def test_can_disable_percentage_of_time_gate_many_times_and_consistently_return_values
    (1..100).each do |percentage|
      assert_equal true, @adapter.disable(@feature, @time_gate, @flipper.time(percentage))
      result = @adapter.get(@feature)
      assert_equal percentage.to_s, result[:percentage_of_time]
    end
  end

  def test_converts_boolean_value_to_a_string
    assert_equal true, @adapter.enable(@feature, @boolean_gate, @flipper.boolean)
    result = @adapter.get(@feature)
    assert_equal 'true', result[:boolean]
  end

  def test_converts_the_actor_value_to_a_string
    assert_equal true, @adapter.enable(@feature, @actor_gate, @flipper.actor(@actor_class.new(22)))
    result = @adapter.get(@feature)
    assert_equal Set['22'], result[:actors]
  end

  def test_converts_group_value_to_a_string
    assert_equal  true, @adapter.enable(@feature, @group_gate, @flipper.group(:admins))
    result = @adapter.get(@feature)
    assert_equal Set['admins'], result[:groups]
  end

  def test_converts_percentage_of_time_integer_value_to_a_string
    assert_equal true, @adapter.enable(@feature, @time_gate, @flipper.time(10))
    result = @adapter.get(@feature)
    assert_equal '10', result[:percentage_of_time]
  end

  def test_converts_percentage_of_actors_integer_value_to_a_string
    assert_equal true, @adapter.enable(@feature, @actors_gate, @flipper.actors(10))
    result = @adapter.get(@feature)
    assert_equal '10', result[:percentage_of_actors]
  end

  def test_can_add_remove_and_list_known_features
    assert_equal Set.new, @adapter.features

    assert_equal true, @adapter.add(@flipper[:stats])
    assert_equal Set['stats'], @adapter.features

    assert_equal true, @adapter.add(@flipper[:search])
    assert_equal Set['stats', 'search'], @adapter.features

    assert_equal true, @adapter.remove(@flipper[:stats])
    assert_equal Set['search'], @adapter.features

    assert_equal true, @adapter.remove(@flipper[:search])
    assert_equal Set.new, @adapter.features
  end

  def test_clears_all_the_gate_values_for_the_feature_on_remove
    actor_22 = @actor_class.new('22')
    assert_equal true, @adapter.enable(@feature, @boolean_gate, @flipper.boolean)
    assert_equal true, @adapter.enable(@feature, @group_gate, @flipper.group(:admins))
    assert_equal true, @adapter.enable(@feature, @actor_gate, @flipper.actor(actor_22))
    assert_equal true, @adapter.enable(@feature, @actors_gate, @flipper.actors(25))
    assert_equal true, @adapter.enable(@feature, @time_gate, @flipper.time(45))

    assert_equal true, @adapter.remove(@feature)

    assert_equal @adapter.get(@feature), {
      :boolean => nil,
      :groups => Set.new,
      :actors => Set.new,
      :percentage_of_actors => nil,
      :percentage_of_time => nil,
    }
  end

  def test_can_clear_all_the_gate_values_for_a_feature
    actor_22 = @actor_class.new('22')
    @adapter.add(@feature)
    assert_includes @adapter.features, @feature.key

    assert_equal true, @adapter.enable(@feature, @boolean_gate, @flipper.boolean)
    assert_equal true, @adapter.enable(@feature, @group_gate, @flipper.group(:admins))
    assert_equal true, @adapter.enable(@feature, @actor_gate, @flipper.actor(actor_22))
    assert_equal true, @adapter.enable(@feature, @actors_gate, @flipper.actors(25))
    assert_equal true, @adapter.enable(@feature, @time_gate, @flipper.time(45))

    assert_equal true, @adapter.clear(@feature)
    assert_includes @adapter.features, @feature.key
    assert_equal @adapter.get(@feature), {
      :boolean => nil,
      :groups => Set.new,
      :actors => Set.new,
      :percentage_of_actors => nil,
      :percentage_of_time => nil,
    }
  end

  def test_does_not_complain_clearing_a_feature_that_does_not_exist_in_adapter
    assert_equal true, @adapter.clear(@flipper[:stats])
  end
end
