use qbit;

use Test::More;

use TestApplication;

my $app = new_ok(TestApplication => []);

is($app->test_model->method(), 12345, 'Checking model\'s mehod call');

done_testing();
