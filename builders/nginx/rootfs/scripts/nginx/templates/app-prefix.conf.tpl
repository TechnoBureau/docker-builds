location ^~ {{location}} {
    alias "{{document_root}}";

    {{acl_configuration}}

    include "/home/nonroot/nginx/conf/product/protect-hidden-files.conf";
}

{{additional_configuration}}
