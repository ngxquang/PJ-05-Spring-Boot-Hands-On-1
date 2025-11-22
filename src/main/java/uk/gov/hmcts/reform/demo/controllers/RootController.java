package uk.gov.hmcts.reform.demo.controllers;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class RootController {

    @GetMapping("/")
    public String index() {
        // Forward nội bộ tới file tĩnh, URL vẫn là "/"
        return "forward:/index.html";
    }
}
