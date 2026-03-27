from src.infra.config.settings import Settings


class TestSettingsDefaults:
    def test_default_env_is_local(self):
        settings = Settings()
        assert settings.env == "local"

    def test_default_postgres_config(self):
        settings = Settings()
        assert settings.postgres_user == "fiscal_guard"
        assert settings.postgres_host == "localhost"
        assert settings.postgres_port == 5432
        assert settings.postgres_db == "fiscal_guard"

    def test_default_redis_url(self):
        settings = Settings()
        assert settings.redis_url == "redis://localhost:6379"

    def test_default_aws_config(self):
        settings = Settings()
        assert settings.aws_access_key_id == "test"
        assert settings.aws_default_region == "us-east-1"
        assert settings.s3_bucket_name == "fiscal-guard-data"


class TestDatabaseUrl:
    def test_database_url_is_computed(self):
        settings = Settings()
        expected = "postgresql://fiscal_guard:fiscal_guard@localhost:5432/fiscal_guard"
        assert settings.database_url == expected

    def test_database_url_reflects_custom_values(self):
        settings = Settings(
            postgres_user="user",
            postgres_password="pass",
            postgres_host="db.example.com",
            postgres_port=5433,
            postgres_db="mydb",
        )
        assert settings.database_url == "postgresql://user:pass@db.example.com:5433/mydb"


class TestLocalstackDefaults:
    def test_local_env_sets_aws_endpoint(self):
        settings = Settings(env="local", aws_endpoint_url=None)
        assert settings.aws_endpoint_url == "http://localhost:4566"

    def test_local_env_does_not_override_custom_endpoint(self):
        settings = Settings(env="local", aws_endpoint_url="http://custom:4566")
        assert settings.aws_endpoint_url == "http://custom:4566"

    def test_non_local_env_keeps_endpoint_none(self):
        settings = Settings(env="prod", aws_endpoint_url=None)
        assert settings.aws_endpoint_url is None
