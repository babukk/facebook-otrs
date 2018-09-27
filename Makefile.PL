use ExtUtils::MakeMaker;

WriteMakefile (
    AUTHOR        => 'Konstantin Bakunov <konstantin.bakunov@gmail.com>',
    ABSTRACT      => 'Facebook-OTRS integration example',
    NAME          => 'Facebook-OTRS',
    PREREQ_PM     => { Getopt::Long=>0, DBI=>0, DBD::SQLite=>0, SOAP::Lite=>0, Log::Log4perl=>0, JSON=>0, LWP::UaerAgent=>0, URI=>0, Endcode=>0, },
    VERSION_FROM  => 'FacebookOTRS.pm',
);
