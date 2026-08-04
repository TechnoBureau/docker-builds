location ^~ {{location}} {
    alias "{{document_root}}";

    {{acl_configuration}}

    include "/tmp/nginx/conf/product/protect-hidden-files.conf";
}

{{additional_configuration}}
